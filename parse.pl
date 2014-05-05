#!/usr/bin/perl

use strict;
use LWP::Simple;

my $base_url = "http://nregalndc.nic.in/netnrega/";
my $resp = get("${base_url}loginframegp.aspx?salogin=Y&state_code=15");

while ($resp =~ /<option value="(15.*?)">(.*?)<\/option>/sig) {
	my $blocks = get("${base_url}homedist.aspx?state_name=KARNATAKA&district_name=$2&District_Code=$1&State_Code=15");
	my $dist_name = ucfirst(lc($2));

	while ($blocks =~ /gvdpc.*?href="(.*?)"/gis) {
		my $url = $1;
		my ($block_name) = $url =~ /block_name=(.*?)\&/;		
		$block_name = ucfirst(lc($block_name));

		$url =~ s/\&amp\;/\&/g;

		my $gp = get($base_url.$url);

		while ($gp =~ /gvpanch.*?href="(.*?)"/gis) {
			my $full_url = $base_url.$1;
			$full_url =~ s#\.\.##;

			my ($gp_name) = $full_url =~ /Panchayat_name=(.*?)&/gis;
			$gp_name = ucfirst(lc($gp_name));

			my ($gp_code) = $full_url =~ /Panchayat_code=(.*)/sig;

			my $data_url = $base_url."writereaddata/state_out/RegCatvill_${gp_code}.html";

#			print "$dist_name,$block_name,$gp_name,$gp_code,$data_url\n";

			sleep 5;

			open my $fh, '>'. "${gp_code}.html";
			print $fh get($data_url);
			close $fh;
		}
	}
}
