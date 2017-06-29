# ****************************************************************
#   Written by Glenn Boyden
#   first created on 2/03/2010
#   Description:  This perl script will read the top.rtf file generated on 
#   one UC server. It will parse out the each process and alert if any are over
#   99% on a single processor
# ****************************************************************


use DBI;
use strict;
use Time::Local; 
use Date::Format;
use MIME::Entity;

sub trim($);
  
my $month;
my $day;
my $year;                          
my $unixtime;
my @f = localtime(time);
$month = strftime("%L",@f);
$day = strftime("%e",@f);
$year = strftime("%Y",@f);

my $noc_mysql_db_ip_address = '172.16.20.83';
my $databasename = '';
my $admin_email_list = 'lauro.boska@siemens-enterprise.com, glenn.boyden@siemens-enterprise.com';
my $notify_email_list = 'lauro.boska@siemens-enterprise.com, Denisa.boss@banctec.com, Steve.fowler@banctec.com,Peter.white@banctec.com, Melisa.gardea@banctec.com,glenn.boyden@siemens-enterprise.com'; 
#my $notify_email_list = 'glenn.boyden@siemens-enterprise.com'; 
my $from_email_user = 'netopscenter.us@siemens-enterprise.com';
my $subject_line = '';
my $preface = '';
my $body = '';

my $dbh1;
my $dbh2;
my $q1;
my $q2;
my $sth1;
my $sth2;
my @row = '0';
my $last_index_id = '0';

my $indx;
my $cap_time;
my $customer_id = 67;
my $sen_date;
my $ip_address;
my $destination = 'trapdest1'; #if script is run on aggregator, use 127.0.0.1 
my $destination2 = 'trapdest2'; #if script is run on aggregator, use 127.0.0.1
my $log_date;
my $host_name;
my $value_id;
my $value;
my $filename;
my $filepath;
my $backupdir = "/home/ggboyden/Documents/perl/banctec/";
my $cap_file = "top.rtf";
my $reg_729;
my $reg_711;
my $reg_711equiv;
my @files;
my $host_cnt;
my $log_file;
my $logtime;
my $line;
my $temp;
my $last_timestamp;
my $last_epoch_time;
my $cnt;
my $val;
my $pos;
my ($year, $mon, $day, $hr, $min, $sec);

my $top_time;
my $uptime_days;
my $uptime_hhmmss;
my $users;
my $pid;
my $user;
my $priority;
my $nice;
my $virtual;
my $resident;
my $shared;
my $state_status;
my $cpu_percent;
my $memory_percent;
my $cpu_time_plus;
my $command_name;
my $threshold = 99;
my $over_threshold = 0;
my $problem_process;

my @top_vars;
my $top_cnt;
my $top_snapshot;
my $var_cnt;
my $var;
my @temp_var;
my $inspect_line_cnt = 0; 
my $attachment1;
my $q1;
my $host ='10.2.9.60';
my $remedy_ticket_message = "";

if ($host eq '10.2.9.120') { $host_name = 'banktec_frontend_120'}; 
if ($host eq '10.2.9.60') { $host_name = 'banktec_backend_60'}; 
if ($host eq '10.2.9.124') { $host_name = 'banktec_media_124'}; 

$filename = ("top_$host_name\_%m-%d-%Y__%H_%M.rtf", localtime);

$filepath = "$backupdir$host/$filename";
$files[$host_cnt] = $filepath;

$log_file = "$backupdir$host/$cap_file";

print "$files[0]\n"; 
print "processing top.rtf file for $host_name.\n";
    #no warnings;
    $attachment1 = $log_file;
    print "$attachment1\n";
    open top_file, "<$log_file" or die $!;
    $inspect_line_cnt = 0; 
    
    while ($line = <top_file>) {
        $cnt = $cnt + 1;
        $temp = trim($line);
        if ($line =~/top -/) { # Process the top line            
            $inspect_line_cnt = 1;
            $top_snapshot = $top_snapshot + 1;        
            @top_vars = split(/,/,$temp);

            foreach (@top_vars) {
                      $var_cnt = $var_cnt + 1;
                      $var = trim($_);                      
                      
                      if ($var_cnt == 1){ #up time days   
                            @temp_var = split(/ /,$var);     
                            $top_time = trim($temp_var[2]); 
                            print "top_time = $top_time ";                                       
                            $uptime_days = trim($temp_var[4]); 
                            print "uptime_days = $uptime_days ";                                       
                      };

                      if ($var_cnt == 2){ #up time hhmmss   
                            @temp_var = split(/up/,$var);     
                            $uptime_hhmmss = $var; 
                            print "uptime_hhmmss = $uptime_hhmmss\n";                                       
                      };
            }; 
           $var_cnt = 0;
        };       

        if  ($inspect_line_cnt > 0){
                $inspect_line_cnt = $inspect_line_cnt + 1; 
                if  ($inspect_line_cnt > 8 and $temp ne "" ){
                      @top_vars = split(/ +/,$temp);
                      $pid = trim($top_vars[0]);
                      $user= trim($top_vars[1]);
                      $priority = trim($top_vars[2]);
                      $nice = trim($top_vars[3]);
                      $virtual = trim($top_vars[4]);
                      $resident = trim($top_vars[5]);
                      $shared = trim($top_vars[6]);
                      $state_status = trim($top_vars[7]);
                      $cpu_percent = trim($top_vars[8]);
                      $memory_percent = trim($top_vars[9]);
                      $cpu_time_plus = trim($top_vars[10]);
                      $command_name = trim($top_vars[11]);
                      if ($cpu_percent > 0){
                            if ($cpu_percent > $threshold){
                                  if ($command_name ne 'nativeRTPunit') {
                                    $over_threshold = $over_threshold + 1;
                                    $problem_process = $problem_process."cpu% = [$cpu_percent%] process = [$command_name]\n";
                                  };                                    
                            };
                            
                      };                                            
            }; 
           $var_cnt = 0;                
        };          
    };
  close(top_file);
  print "\n";
  
 $remedy_ticket_message = "$host_name has a process over threshold. Please investigate if process is stuck and affecting service.";
 
 if ($over_threshold > 2) {                  
         $subject_line = "UC Process Alert - $host_name has a process with a CPU load over $threshold%";
         $preface = "$host_name has a process over $threshold% CPU load\n";
         $preface = $preface.$problem_process;
         print "$preface\n";
         notify_support();        

         #system qq(snmptrap -v 1 -c public $destination 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$host_name\" 1.3.6.1.4.1.999999 s \"$remedy_ticket_message\" 1.3.6.1.4.1.999999 s \"Alarm\" );
         #system qq(snmptrap -v 1 -c public $destination2 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$host_name\" 1.3.6.1.4.1.999999 s \"$remedy_ticket_message\" 1.3.6.1.4.1.999999 s \"Alarm\" );
         #print "sending process over threshold ALARM for $host_name \n";
  };
  
 if ($over_threshold < 3) {                  
      #system qq(snmptrap -v 1 -c public $destination 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$host_name\" 1.3.6.1.4.1.999999 s \"$remedy_ticket_message\" 1.3.6.1.4.1.999999 s \"Clear\" );
      #system qq(snmptrap -v 1 -c public $destination2 1.3.6.1.2.1.27.6 \'\' 6 1 \'\' 1.3.6.1.4.1.999999 s \"$host_name\" 1.3.6.1.4.1.999999 s \"$remedy_ticket_message\" 1.3.6.1.4.1.999999 s \"Clear\" );
      print "sending process over threshold CLEAR for $host_name \n";
  };
               
  exit;

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
};

sub notify_support {
  my $sendToAddress = $notify_email_list;
	my $myEmailAddress = $from_email_user;
	my $mail;
	$mail = MIME::Entity->build(
      Type =>"multipart/mixed", 
			From =>$myEmailAddress,
			To =>$sendToAddress,
      Subject => $subject_line);
   
	### Add Attachement 1 (the body)
	$body = "The Siemens NOC UC Process Monitor has detected an issue.\n\n";
  $body = $body."Please see the attached capture of TOP command output for complete details.\n";
  $body = $body."Below are a summary of the values that surpassed the threshold settings.\n\n";
  $body = $body.$preface;

	$mail->attach(
   			Type     => 'TEXT',
		    Data     => $body
	);
	my $attachment1 = $log_file;
	### Send the message with attachment
	$mail->attach(Path => $attachment1, Type => 'TEXT', Encoding => "base64");
	open MAIL,"|/usr/lib/sendmail -t -oi -oem" or die"open: $!";
	$mail ->print(\*MAIL);
	close MAIL;
}
