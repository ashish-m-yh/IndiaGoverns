#!/usr/bin/perl

use strict;

my $list_mode = 1;

local $/=undef;

foreach my $file (@ARGV) {
	open my $fh, '<', $file or die $!;
	my $data = <$fh>;
	close $fh;

	my %loc;

	while ($data =~ /(District|Block|Panchayat).*?<b>(.*?)<\/b>/isg) {
		$loc{$1} = ucfirst(lc($2));
	}

	if ($list_mode) {
		$file =~ s/\.html//;

		if ($loc{'District'} && $loc{'Block'} && $loc{'Panchayat'}) {
			print $file,',',$loc{'District'},',',$loc{'Block'},',',$loc{'Panchayat'},"\n";
		}

		next;
	}

	while ($data =~ s/<tr>(.*?)<\/tr>//s) {
		my $text = $1;

		my @match;

		while ($text =~ s/<font.*?color='red'\s*>(.*?)<\/font>//s) {
			push @match, $1;
		}

		if ($match[0] =~ /Household/i) {
			unshift @match,"","","","";
			if ($file eq $ARGV[0]) {
				print join(",", @match),"\n";
			}
		}
		elsif ($match[0] =~ /Total/i) {
			unshift @match,"","","";
			print join(",", @match),"\n\n";
		}
		elsif ($match[0] eq '') {
			my @arr;

			foreach (@match) {
				if ($_ =~ /Village/) {
					shift @arr;
					shift @arr;
					unshift @arr, 'District', 'Block', 'Panchayat';
				}

				push @arr, $_;
				push @arr, ' ' unless $_ =~ /Village|Male/i;
			}

			if ($file eq $ARGV[0]) {
				print join(",", @arr),"\n";
			}
		}
		else {
			shift @match;
			$match[0] = ucfirst(lc($match[0]));
			unshift @match,$loc{'District'},$loc{'Block'},$loc{'Panchayat'};
			print join(",", @match),"\n";
		}
	}
}
