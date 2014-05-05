#!/usr/bin/perl

use strict;

use Carp qw(carp croak);
use IO::File;
use XML::Simple;

my %cache;

use constant { 
	LVL => 0,
	YEAR_POS => 0,
	DATA_COL_POS => 1,
	QUERY_URL => 2,
	INFO_URL => 3,
};

my $conf = XMLin(shift);
my $type = shift;

my $base_url = $conf->{'base_url'};
my $infile   = $conf->{$type}->{'input_file'};
my $outdir   = $conf->{$type}->{'output_dir'};
my $levels   = $conf->{$type}->{'level'};

my @meta = (
		[ $levels->[0]->{'regex'}, $levels->[0]->{'colpos'}, $levels->[0]->{'form_url'}, $levels->[0]->{'output_url'} ],
		[ $levels->[1]->{'regex'}, $levels->[1]->{'colpos'}, $levels->[1]->{'form_url'}, $levels->[1]->{'output_url'} ],
		[ $levels->[2]->{'regex'}, $levels->[2]->{'colpos'}, $levels->[2]->{'form_url'}, $levels->[2]->{'output_url'} ],
	   );

undef $levels;

my $gc = 0;

my $out_fh = new IO::File ("> $outdir/output.txt") or carp $!;

open my $fh, "<", $infile or carp $!;
while (<$fh>)
{
	chomp;

	my @row = split(/\,/, $_);
	my $year = $row[YEAR_POS];
	$year =~ s/\d{2}(\d{2})-(\d{2})/$1$2/;

	my @stk=();

	foreach (@meta)
	{
		my $v = $row[$_->[DATA_COL_POS]];
		last if (lc($v) eq 'all');
		push @stk, lc ($v);
	}

	my $v = get_id_array(\@stk,$year);
	my $num = grep { defined $_ } @$v;

	unless ($num == 3) { 
		carp "WARNING: Mapping was not found for @row at row\t", ++$gc;
		use Data::Dumper;
		print Dumper(\@stk);
		next;
	}

	my $ctr = 0;
	my $post_params = join('&', map { qq!$meta[$ctr++]->[LVL]=$_! } @$v);
	my $url = "$base_url$year".$meta[$ctr-1]->[INFO_URL];

	write_row($url,$post_params,\@row,$out_fh);
}
close $fh;

$out_fh->close;	

sub get_id_array
{
	my ($v, $year) = @_;
	my $num_levels = @$v-1;

	for (0 .. $num_levels)
	{
		my $query = join('&', map { "$meta[$_]->[LVL]=$v->[$_]" } (0 .. $_-1));

		my $cmd = "curl -s ${base_url}${year}$meta[$_]->[QUERY_URL]";
		$cmd .= " -d '$query'" if $query;

		my $out = `$cmd`;
		$v->[$_] = $cache{$meta[$_]->[LVL]}->{lc($v->[$_])} || extract_pat($out,$meta[$_]->[LVL],$v->[$_]);
	}

	return $v;
}

sub write_row
{
	my ($url, $post, $row, $handle) = @_;

	my $cmd = "curl -s -d '$post' $url";
	my $out = `$cmd`;

	my $ctr = 0;

	if (defined $handle) {	
		while ($out =~ s/<td>(.*?)<\/td>//is)
		{
			my $match = $1;
			$match =~ s/\s+//gis;
			$match =~ s#<strong>(.*?)</strong>#$1\t#gis;		

			++$ctr;

			print $handle join("\t", @$row,'') if ($ctr % 2 == 1);
			print $handle $match;
			print $handle (($ctr % 2 == 0) ? "\n" : "\t");
		}
	}
}

sub extract_pat
{
	my ($out, $level, $label) = @_;

        if ($out =~ m#<select\s+id=$level.*?>(.*?)</select>#si)
        {
                my $match = $1;

                while ($match =~ m#option.*?value="(.*?)"\s*>\"?(.*?)\"?</option#gi)
                {
			$cache{$level}->{lc($2)} = $1 if ($2 ne '' && $1 ne '');
                }
        }

	return $cache{$level}->{$label};
}
