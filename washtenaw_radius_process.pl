#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 2/22/2007
#   Description:  This perl script will read in all of the RADIUS 
#   tickets in a directory and load them into a MySQL database.
# ****************************************************************

use DBI;
use strict;
use Time::Local; 
use Date::Format;
use Time::Interval;

my $month;
my $day;
my $year;
my $unixtime;
my @f = localtime(time);
$month = strftime("%L",@f);
$day = strftime("%e",@f);
$year = strftime("%Y",@f);

print "$month-$day-$year\n"; 

$unixtime = timelocal(0,0,0,$day,$month-1,$year) * 1000;
print $unixtime."\n";

# NOC's mysql database connection 1
print "Connecting to Siemens NOC's database\n";
my $dbh1 = DBI->connect("dbi:mysql:washtenaw:127.0.0.1",undef,undef) or die "Unable 
to connect to NOC database";

my $filepattern = '*.txt';
my $filepath = '/home/ggboyden/Documents/radius/*.txt';
my $fh;
my @filelist = </home/ggboyden/Documents/radius/*.txt>;
my $file;
my $filecnt = 0;


foreach $file (@filelist) {
	#print "$file\n";
	$filecnt = $filecnt + 1;
}
print "File count = $filecnt\n";

my $readline;
my $reccnt = 0;
my $user_name;
my $user_class;
my $timestamp;
my $bytes_up;
my $bytes_down;
my $session_time;
my $status;
my $session_id;
my $nas_port;
my $q1;
my $sth1;

foreach $file (@filelist) {

	open ($fh, $file) or die "Could not open file $file $!\n";
	while (<$fh>) {
		chomp;
		$readline = "$_";

		#Get User Name
		if($readline =~ /User-Name/) {	
			$user_name = substr($readline, index($readline,"="));
			$user_name =~ s/"//g; # Remove quotes
			$user_name =~ s/=//g; # Remove equals sign
			$user_name =~ s/ //g; # Remove spaces
			$user_class= substr($user_name, 0, index($user_name,"__"));
			$user_name = substr($user_name,index($user_name,"__")+2);
			$user_name =~ tr/[__]//; # Remove __
			$user_name = substr($user_name, 0, index($user_name,'@wip'));
		}

		#Get Acct-Status-Type 
		if($readline =~ /Acct-Status-Type/) {	
			$status = substr($readline, index($readline,"="));
			$status =~ s/"//g; # Remove quotes
			$status =~ s/=//g; # Remove equals sign
			$status =~ s/ //g; # Remove spaces
		}

		#Get Acct-Session-Id
		if($readline =~ /Acct-Session-Id/) {	
			$session_id = substr($readline, index($readline,"="));
			$session_id =~ s/"//g; # Remove quotes
			$session_id =~ s/=//g; # Remove equals sign
			$session_id =~ s/ //g; # Remove spaces
		}

		#Get NAS-Port
		if($readline =~ /NAS-Port-Id/) {	
			$nas_port = substr($readline, index($readline,"="));
			$nas_port =~ s/"//g; # Remove quotes
			$nas_port =~ s/=//g; # Remove equals sign
			$nas_port =~ s/ //g; # Remove spaces
		}

		#Get bytes up
		if($readline =~ /Acct-Output-Octets/) {	
			$bytes_up = substr($readline, index($readline,"="));
			$bytes_up =~ s/"//g; # Remove quotes
			$bytes_up =~ s/=//g; # Remove equals sign
			$bytes_up =~ s/ //g; # Remove spaces
		}

		#Get bytes down
		if($readline =~ /Acct-Input-Octets/) {	
			$bytes_down = substr($readline, index($readline,"="));
			$bytes_down =~ s/"//g; # Remove quotes
			$bytes_down =~ s/=//g; # Remove equals sign
			$bytes_down =~ s/ //g; # Remove spaces

		}

		#Get session_time
		if($readline =~ /Acct-Session-Time/) {	
			$session_time = substr($readline, index($readline,"="));
			$session_time =~ s/"//g; # Remove quotes
			$session_time =~ s/=//g; # Remove equals sign
			$session_time =~ s/ //g; # Remove spaces
		}

		# Timestamp - Last Record - Add Record to MySQL
		if($readline =~ /Timestamp/) {
			$reccnt = $reccnt + 1;
			$timestamp = substr($readline, index($readline,"="));
			$timestamp =~ s/"//g; # Remove quotes
			$timestamp =~ s/=//g; # Remove equals sign
			$timestamp =~ s/ //g; # Remove spaces
			#print "user:$user_class name:$user_name ts:$timestamp dn:$bytes_down up:$bytes_up duration:$session_time\n";

			# Insert the processed data into Event_processed table
			$q1 = "INSERT radius_tickets 
					set user_name = \'$user_name\', 
					user_class = \'$user_class\', 
					bytes_down = $bytes_down, 
					bytes_up = $bytes_up, 
					duration = $session_time, 
					wip_timestamp = $timestamp,
					status = \'$status\',
					session_id = \'$session_id\',
					nas_port = \'$nas_port\',
					radius_file_name = \'$file\'";
			#print "$q1\n";
			$sth1 = $dbh1->prepare($q1);
			$sth1->execute or die "Unable to execute query";			
			# Clear variables
		      $user_name = ''; 
			$user_class = ''; 
			$bytes_down = 0; 
			$bytes_up = 0; 
			$session_time = 0; 
			$timestamp = 0; 
			$status = ''; 
			$session_id = ''; 
			$nas_port = '';
 		
		}


	}
	close ($fh);
	print "$file\n";
}
print "Record count = $reccnt\n";

$dbh1->disconnect;

print "Disconnecting from NOC database\n";
$dbh1->disconnect;

exit;
