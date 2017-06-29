#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   Last updated on 2/25/2009
##################################################################################
#Modules used
  use Expect;
  use strict;
  use POSIX;
  use Proc::Queue size => 10, debug => 1;
  use POSIX ":sys_wait_h";
  use DBI;
  use Spreadsheet::WriteExcel;
	use Net::SCP::Expect;
  use MIME::Entity;

#These variables change with each upgrade and city
my $customer_name = 'att';
my $ap_user_name = 'root';
my $ap_password = 'T0t0';
my $tftp_server = '10.102.16.254';
my $admin_email_list = 'dfw8888@yahoo.com, glenn.boyden@siemens.com, adam.nolley.ext@siemens.com, netopscenter.us@siemens.com';
my $ap_select = 'SELECT ip_address, noc_device_name, building as bap, rack as model_number, room as zone FROM devices
                where customer_id = 38 and noc_device_name like \'att_riv%\' and
                (room = \'Zone 39\' or room = \'Zone 54\' or room =\'Zone 36\')
                order by rack desc, room';
my $tftp_folder = "BelairSW_808G_BA";                

#Variables used
$| = 1;
my $nc = 1;
my $promptchar = '#';
my $filename;
my $filepath;
my $backupdir = "/home/ggboyden/Documents/perl/$customer_name/";
my $timeout = 200;
my @logfile;
my $line;
my @hosts;
my $files = "";
my $file = "";
my $host_cnt = 0;
my $host_name = "";
my $body = "";
my $subject_line = "";
my $from_email_user = 'netopscenter.us@siemens.com';
my $sendToAddress = '';
my $myEmailAddress = $from_email_user;
my $preface ="";
my @lines = "";
my $output;
my $temp = 0; 
my $cap_file = "";
my $cnt = 0;
my $host = '';
my @row = '';
my @noc_device_name = '';
my @bap = '';
my @model_number = '';
my @zone = '';
my $q1 = '';
my $sth_noc = '';
my $command = '';

 	

$filename = strftime("$customer_name\_upgrade_results_%m-%d-%Y__%H_%M.rtf", localtime);
$filepath = "$backupdir/$filename";
$files = $filepath;

print "Connecting to Siemens NOC's database\n";
my $dbh_noc = DBI->connect("dbi:mysql:noc_core:172.16.20.83","nocautomation","") or die "Unable to connect to NOC database";


  $q1 = $ap_select;
	# execute the query
 	$sth_noc = $dbh_noc->prepare($q1);
 	$sth_noc->execute or die "Unable to execute query";
  print "obtaining list of radios to upgrade, starting with model 200s\n";  
 	
   while(@row = $sth_noc->fetchrow_array) {
 		$hosts[$cnt] = $row[0];
 		$noc_device_name[$cnt] = $row[1];
 		$bap[$cnt] = $row[2];
 		$model_number[$cnt] = $row[3];
 		$zone[$cnt] = $row[4];
 	  print " $hosts[$cnt] - $noc_device_name[$cnt] - $model_number[$cnt] - $bap[$cnt] - $zone[$cnt]\n";
 	  $cnt = $cnt + 1;
 	}



foreach $host (@hosts)   {         
          my $command = Expect->spawn("ssh $ap_user_name\@$host");
          
          eval {
              $command->expect($timeout, -re => "Password:") or die MyFileException->new("Failed to get password prompt");
              next;
          };
          
          if ($@) {
              print "$customer_name upgrade automation timed out at login";
              next;
          };
          
          print $command "$ap_password\r";
          eval {
              $command->expect($timeout, -re => "$promptchar") or die MyFileException->new("Failed to get shell prompt - bad password?");    
              next;
          };
          
          if ($@) {
              $subject_line = "$customer_name upgrade script - password was rejected";
              #call_for_password_reject();
              #exit;
          };
          sleep 1;
          $command->log_file("$filepath");
          sleep 1;
          $command->send("cd system\r");
          sleep 1;
          $command->expect($timeout, -re => "$promptchar");
          sleep 1;
          $command->send("show loads\r");
          sleep 1;
          $command->expect($timeout, -re => "$promptchar");
          sleep 1;
          print "upgrade load remoteip 10.102.16.254 remotepath $tftp_folder$model_number[$cnt] tftp\n";
          $command->send("upgrade load remoteip 10.102.16.254 remotepath $tftp_folder$model_number[$cnt] tftp\r");
          sleep 1;
          eval {
              $command->expect($timeout+600, -re => "$promptchar") or die MyFileException->new("upgraded failed");    
              next;
          };
          sleep 1;                         
          $command->send("show loads\r");
          sleep 2;    
          $command->send("exit\r");
          sleep 1;  
}    

$host = "";
$filename = "";

exit;

