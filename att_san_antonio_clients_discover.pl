#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 4/21/2008
#   Description:  This perl script will capture the current user 
#   MAC addresses in the Belair v8 network and store then in a table
#   This data will be used by the Service Desk to help find where
#   users are in the network. 
# ****************************************************************

use DBI;
#use strict;
use Time::Local; 
use Date::Format;
use Time::Interval;use Net::Telnet ();


# NOC's mysql database connection 1
print "Connecting to Siemens NOC's database\n";
my $dbh1 = DBI->connect("dbi:mysql:noc_core:172.16.20.83","nocautomation","") or die "Unable 
to connect to NOC database";

# NOC's mysql database connection 1
print "Connecting to Siemens NOC's database\n";
my $dbh2 = DBI->connect("dbi:mysql:noc_core:172.16.20.83","nocautomation","") or die "Unable 
to connect to NOC database";


# List all San Antonio 100 Radios
my $q1 = "SELECT devices.ip_address FROM devices, customers where customers.customer_id = devices.customer_id and devices.noc_device_name like \'att_san%\' and devices.model like \'MR-100%\'";
#print "\n".$q1."\n";

my $sth1 = $dbh1->prepare($q1);
$sth1->execute or die "Unable to execute query";

my @row;
my @unl; # unl = unreachable node list
my @downtime; 
my @eventtext;
my $cnt = 1;
my @lines = "";
my $host = "";
my $response = "";
my $position = "";
my $telneterror = "";
my $t = "";
my @host_array;
my $responselines = "";
my $ignore = 0;


# populate the array with the node IP values
while(@row = $sth1->fetchrow_array) {
	$host_array[$cnt] = $row[0];
	$cnt = $cnt + 1;
}


$t = new Net::Telnet (Timeout => 10, Errmode => "return"); 
foreach $host (@host_array)
{
		#*****************************************
		eval {
			my $Telnt = $t->open($host) or warn ("unable to telnet into $host\n"); 
		};
		if ($@) { 
			print @$ ->getErrorMessage ();
		}
		print $host;
		print " ";
		$t->login('root', 'admin123'); 
		@lines = $t->cmd("version\n"); 
		chomp(@lines);
		$response = "@lines";

		$position = index($response, "BA100");
		if  ($position > 0  ){
			print "BA100 ";
		};

		$position = index($response, "BA200");
		if  ($position > 0 ){
			print "BA200 -  no ARM modules active\n";
			next;
		};

		$t->cmd("cd /interface/wifi-2-1\n"); 
		@lines = $t->cmd("show clients\n"); 
		#chomp(@lines);
		$response = "@lines";
		my $lngth = length($response);

		if ($lngth  == 0) {
			$host = '';
			next;
		};

		$position = index($response,"No clients associated");
		#print $position,"\n";
		if  ($position > 0){
			print "no clients\n";
		}else {			
			print "clients found\n";

			my @values = split("\n", $response);
			foreach $responselines (@values){
				$ignore = 0;
				$position = index($responselines, "mac addr");
				if  ($position > 0 ){
					$ignore = 1;
				};


				$position = index($responselines, "---");
				if  ($position > 0 ){
					$ignore = 1;
				};


				$position = index($responselines, "]");
				if  ($position > 0 ){
					$ignore = 1;
				};


				if  ($ignore == 0 ){
					#print "<<".$responselines.">>\n";
					my @data = split(" ",$responselines);
					#print "SS-ID =[".$data[0]."]\n";
					#print "vlan =[".$data[1]."]\n";
					#print "mac addr =".$data[2]."\n";
					#print "time =[".$data[3]."]\n";
					#print "ip address =[".$data[4]."]\n";
					#print "rssi =[".$data[5]."]\n";
					#print "auth =[".$data[6]."]\n";
					#print "dhcp =[".$data[7]."]\n";

					# insert datainto List all San Antonio 100 Radios
					my $q2 = "insert into network_mac_history set cap_time = now(), radio_ip_address = \'".$host."\', ssid = \'".$data[0]."\', vlan = \'".$data[1]."\', mac_address = \'".$data[2]."\', connect_time = \'".$data[3]."\', customer_ip_address = \'".$data[4]."\', rssi = \'".$data[5]."\', auth = \'".$data[6]."\', dhcp = \'".$data[7]."\'";

					my $sth2 = $dbh1->prepare($q2);
					$sth2->execute or die "Unable to execute query";

					#print "\n".$q2."\n";

				};									
			}
		};
#print $telneterror;
};

$sth1->finish;
print "Disconnecting from NOC database\n";
$dbh1->disconnect;

exit;
