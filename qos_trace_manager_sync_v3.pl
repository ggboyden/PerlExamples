#!/usr/bin/perl -w
# ****************************************************************
#   Written by Glenn Boyden
#   created on 1/28/2012
#   Description:  This perl script will connect into Boca 
#   Test Trace Manager and Query Database BocaFT5 for QoS data 
#   located in both the PerfData and CallID tables.  It will pull down a
#   CSV Tab delimited file and parse it into it's individual fields, stripping
#   away the quote charcters.
#   This will be performed each 5 minutes.
#
# ****************************************************************

	#use strict;
	use DBI;
  use Socket;

  my @columns;
  my $file = 'qos.csv';
  my $fh;
  sub removequotes($);
  sub ip2int($);
	my @row ="";
	my $today;
  #my $dbserver = "dbi:mysql:noc_core:172.16.20.87";
  my $dbserver = "dbi:mysql:qos_core:172.16.20.83";
  my $arg1 = "nocautomation";
  
  #my $Customer_ID = 67;
  #my $QoS_Source_Type = 'OSV Trace Manager';
  #my $QoS_Source_IP = ip2int ('172.20.34.21');  
  #my $QoS_TM_DB_Name = 'BocaFT5';
  #my $QoS_CannedQuery_Index_No = '105';
  my $Device_ID = 1;
  
  my $CallID;
  my $CallDate;
  my $TMFile;
  my $CallDataSent;
  my $CallDataRecv;
  my $QoS_Loss;
  my $QoS_Jitter;
  my $QoS_Latency;
  my $QoS_Duplicates;
  my $EncodingA;
  my $EncodingB;
  my $DNA;
  my $DNB;
  my $DeviceVersion;
  my $CallIdx;
  my $IPNumber;
  my $IPA;
  my $IPB;
  my $IPNumA;
  my $IPNumB;
  my $CallStart;
  my $CallDuration;
  my $FileIDs;
  my $CallDisposition;
  my $CallSignature;
  my $TraceManagerMessages;
  my $Primaryphonenum;
  my $IPAddress;
         
  
  my $TempSQL = "";
  my $modulus = "";
  my $q1 = "";
  my $sth1 = "";
  my $arg2 = "secret1";
  
# Get latest data from Boca Trace Manager 
  my $cmd = "wget --output-document=qos.csv --no-check-certificate \"https://172.20.34.21:28081/FADE/public/index.php/builder/run/pagetype/runquery/top/OSV/sys/BocaFT5/id/62?display=csv&days=5\"";
  system("$cmd");
  if ( $? == -1 )
  {
    print "wget command failed: $!\n";
    exit;
  }
  else
  {
    printf "command compeleted\n\n";
  }
 	# NOC's mysql database connection 1
  print "Connecting to Siemens NOC's database\n";
 my $dbh1 = DBI->connect($dbserver,$arg1,$arg2) or die "Unable 
  to connect to NOC database";

  open($fh, "< $file") or die "Could not open $file";
  
      while(my $line=<$fh>){
         # skip sep= and columns name lines     		 
     		 next unless $. > 3;
         $line = removequotes($line);
         chomp ($line);
	       if ($line eq " No Data Found") {
			         print "No Data Found - Exiting\n\n";
			         unlink ($file);
 	             print "Disconnecting from NOC database\n";
	             $dbh1->disconnect;
               exit;
     		 };
     		 #print "$line\n";
	       if ($. > 200000) {
			         exit;
     		 };
         # skip sep= and columns name lines     		 
     		 next unless $. > 5;
     		 @columns = split("\t", $line);
     		 print ("$. Loss=",$columns[5]," Jitter=", $columns[6]," Latency=", $columns[7]," Duplicates=", $columns[8],"\n");
         #Clear variables then update database with information
         $CallID = "";
         $CallDate = "";
         $TMFile = "";
         $CallDataSent = "";
         $CallDataRecv = "";
         $QoS_Loss = "";
         $QoS_Jitter = "";
         $QoS_Latency = "";
         $QoS_Duplicates = ""; 
         $EncodingA = "";
         $EncodingB = "";
         $DNA = "";
         $DNB = "";
         $DeviceVersion = "";
         $CallIdx = "";
         $IPNumber = "";
         $IPA = "";
         $IPB = "";
         $IPNumA = "";
         $IPNumB = "";
         $CallStart = "";
         $CallDuration = "";
         $FileIDs = "";
         $CallDisposition = "";
         $CallSignature = "";
         $TraceManagerMessages = "";
         $Primaryphonenum = "";
         $IPAddress = "";

         $CallID = $columns[0];
         $CallDate = $columns[1];
         $TMFile = $columns[2];
         $CallDataSent = $columns[3];
         $CallDataRecv = $columns[4];
         $QoS_Loss = $columns[5];
         $QoS_Jitter = $columns[6];
         $QoS_Latency = $columns[7];
         $QoS_Duplicates = $columns[8];
         $EncodingA = $columns[9];
         $EncodingB = $columns[10];
         $DNA = $columns[11];
         $DNB = $columns[12];
         $DeviceVersion = $columns[13];
         $CallIdx = $columns[14];
         #$IPNumber = ip2int($columns[15]);
         $IPA = ($columns[16]);
         $IPB = ($columns[17]);
         $IPNumA = ($columns[18]);
         $IPNumB = ($columns[19]);
         $CallStart = $columns[20];
         $CallDuration = $columns[21];
         $FileIDs = $columns[22];
         $CallDisposition = $columns[23];
         $CallSignature = $columns[24];
         $TraceManagerMessages = $columns[25];
      
         #figure out what is primary
         $Primaryphonenum = ($IPA eq '8.0.0.0') ? $DNB : $DNB;
         $IPAddress =  ($IPA eq '8.0.0.0') ? $IPB : $IPA;
         $IPNumber = ($IPA eq '8.0.0.0') ? ip2int($IPB) : ip2int($IPA);
      
         #Prepare SQL
         $TempSQL = "insert IGNORE into qos_data ";
         $TempSQL = $TempSQL."set call_id = \'$CallID\',";
         $TempSQL = $TempSQL."device_id = $Device_ID,";
         $TempSQL = $TempSQL."call_date = \'$CallDate\',";
         $TempSQL = $TempSQL."tm_file = $TMFile,";
         $TempSQL = $TempSQL."data_sent = $CallDataSent,";
         $TempSQL = $TempSQL."data_recv = $CallDataRecv,";
         $TempSQL = $TempSQL."loss = $QoS_Loss,";
         $TempSQL = $TempSQL."jitter = $QoS_Jitter,";
         $TempSQL = $TempSQL."latency = $QoS_Latency,";
         $TempSQL = $TempSQL."duplicates = $QoS_Duplicates,";
         $TempSQL = $TempSQL."encoding_a = \'$EncodingA\',";
         $TempSQL = $TempSQL."encoding_b = \'$EncodingB\',";
         $TempSQL = $TempSQL."phone_number = \'$Primaryphonenum\',";
         $TempSQL = $TempSQL."dna = \'$DNA\',";
         $TempSQL = $TempSQL."dnb = \'$DNB\',";
         $TempSQL = $TempSQL."device_version = \'$DeviceVersion\',";
         $TempSQL = $TempSQL."call_idx = $CallIdx,";
         $TempSQL = $TempSQL."ip_address = \'$IPAddress\',";
         $TempSQL = $TempSQL."ip_number = \'$IPNumber\',";
         $TempSQL = $TempSQL."ipa = \'$IPA\',";
         $TempSQL = $TempSQL."ipb = \'$IPB\',";
         $TempSQL = $TempSQL."call_start = \'$CallStart\',";
         $TempSQL = $TempSQL."call_duration = \'$CallDuration\',";
         $TempSQL = $TempSQL."file_ids = \'$FileIDs\',";
         $TempSQL = $TempSQL."call_disposition = \'$CallDisposition\',";
         $TempSQL = $TempSQL."call_signature = \'$CallSignature\'";
         print "\n\n$TempSQL\n\n";
         $sth1 = $dbh1->prepare($TempSQL);
       	 $sth1->execute or die "Unable to execute query";
         $TempSQL = "Insert IGNORE into qos_messages ";
         $TempSQL = $TempSQL."set call_id = \'$CallID\',";
         $TempSQL = $TempSQL."message = \'$TraceManagerMessages\'";
         $sth1 = $dbh1->prepare($TempSQL);
       	 $sth1->execute or die "Unable to execute query";                                
      }
  close ($fh);
  #delete qos.csv
  #unlink ($file);
  $sth1->finish;
 	print "Disconnecting from NOC database\n";
	$dbh1->disconnect;
 exit;

sub ip2int($)
{
  my $int = unpack("l*", pack("l*", unpack("N*", inet_aton(shift))));
  return sprintf("%u", $int);
}
  

sub removequotes($)
{
my $string = shift;
	$string =~ s/'//g;
	$string =~ s/"//g;
	return $string;
}
                     
  
