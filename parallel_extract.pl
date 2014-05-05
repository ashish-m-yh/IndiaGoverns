#!/usr/bin/perl -w

use strict;
use Parallel::ForkManager;
use DB_File;

tie %ids, "/home/ashishin/id.db" or die $!; 

my $url = "http://stg1.kar.nic.in/samanyamahiti/SMEnglish_0506";
my $base_url = "$url/ham_query.asp";
my $extract_conf = [
			"SELECT id=dist(.*?)Taluk",
			"SELECT id=taluk(.*?)village",
			"SELECT id=village(.*?)hamlet",
			"id=hamlet(.*)",
		   ];

my $cmd = "curl -s $base_url";
my $out = `$cmd`;
my @dist = @{extract_pat($out, $extract_conf->[0])};

foreach my $dist (@ARGV)
{
	$cmd = "curl -s -d 'dist=$dist' $base_url";
	$out = `$cmd`;

	my @taluk = @{extract_pat($out, $extract_conf->[1])};

	foreach my $taluk (@taluk)
	{
		my $cmd = "curl -s -d 'dist=$dist&taluk=$taluk' $base_url";
		$out = `$cmd`;
		
		my @vills = @{extract_pat($out, $extract_conf->[2])};

		my $pm = new Parallel::ForkManager(20);

		foreach my $vill (@vills)
		{
			my $pid = $pm->start and next;

			my $cmd = "curl -s -d 'dist=$dist&taluk=$taluk&village=$vill' $base_url";
			$out = `$cmd`;

			my @hamlets  = @{extract_pat($out, $extract_conf->[3])};

			foreach my $ham (@hamlets)
			{
				my $fact_url = "$url/ham_details.asp";

				my $fname = "/home/ashishin/india_gov/data_${dist}_${taluk}_${vill}_${ham}.html";
				open FH, ">$fname" or die $!;

				foreach my $sec (1 .. 21)
				{
					my $cmd = "curl -s -d 'dist=$dist&taluk=$taluk&village=$vill&hamlet=$ham&sector=$sec' $fact_url";
					$out = `$cmd`; 
					print FH "Sector: $sec\n\n$out";
				}
			
				close FH;
			}
				
			$pm->finish;
		}

		$pm->wait_all_children;
	}
}

sub extract_pat
{
	my ($out, $pat, $func) = @_;

	my @elts;

	if ($out =~ m#$pat#si)
	{
		my $match = $1;

		while ($match =~ m#option.*?value="(.*?)"\s*>(.*?)</option#gi)
		{
			if ($1 ne '') 
			{
				if ($func)
				{
					$func->($1);
				} 
				else
				{
					push @elts, $1;
				}
				
				$ids{$1} = $2;
			}	
		}	
	}

	return \@elts;
}

untie %ids;
