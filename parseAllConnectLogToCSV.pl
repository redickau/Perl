#!/usr/bin/perl
use warnings;
use autodie;
use Path::Class;
use Tie::File;

print "\nBeginning the parse:\n";

# create file variable and a pointer to it, create a flag that determines when we write to a new file
my $file = file("$ARGV[0]");
my $delimited_file = $file."_Parsed.csv";
my $file_handle = $file->openr();
my $write_flag = 0;

# list of patterns to match representing the beginning of a new request
my @requestPatterns = (
    qr/Request:[\s]?<customer/,
    qr/Request:[\s]?<order/
    );

# list of patterns to match representing the end of the current request
my @endPatterns = (
    qr/^<\/customerManagementRequestResponse>$/,
    qr/^<\/orderManagementRequestResponse>$/
    );

# create a new file
my $newFile = "allConnectLogOutput";

# open the file for writing and appending
open(OUT_FILE, '>>'.$newFile);

# iterate through the original log file line by line writing certain lines to a new file
while( my $line = $file_handle->getline() ) {

    # if the current line matches a startPattern update the line variable and the flag 
    # so that we continue writing to the new file since this is the start of a request
    if ($line ~~ @requestPatterns) {
	my @trunc_line = split(/Request:[\s]?/, $line);
	$line = $trunc_line[1];
        $write_flag = 1;
    }

    # if the flag value equals 1 print the current line to the new output file
    # else nothing will happen and we simply iterate to the next line
    if ($write_flag == 1) {
	print OUT_FILE "$line";
    }
   
    # if the current line matches an endPattern print it to the new output file and update 
    # the flag so we don't write anything else since this is the end of the request
    if ($line ~~ @endPatterns) {
	$write_flag = 0;
    }
}

# close the pointers to the files we opened
close $file_handle;
close OUT_FILE;

print "Pulling requests from original file...\n";

#   All necessary requests have been added to a new file. The next step is to double all quotations within the newly parsed file.   #
#-----------------------------------------------------------------------------------------------------------------------------------#

# read in the entire parsed file to one variable
$file_out = file("allConnectLogOutput");
$file_handle = $file_out->openr();

# create another new file
$newFile = "allConnectLogOutputCSV";

# open the file for writing and appending
open(OUT_FILE, '>>'.$newFile);

# print a " at the beginning of the file
print OUT_FILE "\"";

# search and replace all other " with ""
while( $line = $file_handle->getline() ) {

    $line =~ s/"/""/g;
    print OUT_FILE $line;
}

# close the parsed file with doubled quotes
close OUT_FILE;
close $file_handle;

print "Formatting the extracted requests...\n";

#   The file now begins with a " and all quotations within have been doubled for formatting purposes in excel. The next step is 
#   to insert single "s after the end tag of each request and before the open tag of the request on the next line. This format
#   will allow each request to occupy one cell within the same column. So, all requests will be listed vertically.
#-----------------------------------------------------------------------------------------------------------------------------------#

# open the newly created file for reading
$file_out_csv = file("allConnectLogOutputCSV");
$file_handle = $file_out_csv->openr();

# set a flag to mark when the end of a request is read
my $end_pattern = 0;

# open the .csv file for writing and appending
open(CSV_OUT, '>>'.$delimited_file);

# iterate through the parsed file line by line
while( $line = $file_handle->getline() ) {
    
    #reset the flag for each line
    $end_pattern = 0;

    # if the current line matches the end tag of a request 
    # remove the newline character, set the end patter flag to true
    # and add a " to the end of the line
    if ($line ~~ @endPatterns) {
	my @no_newline = split("\n", $line);
	$line = $no_newline[0];
	$line =~ s/$line/$line\"/;
	$end_pattern = 1;
    }
 
    # print the current line to the .csv file
    print CSV_OUT $line;

    # if the line just printed was an end tag replace 
    # the removed newline character here and add a " for 
    # the beginning of the next line (which will always 
    # be the open tag of the next request)
    if ($end_pattern == 1) {
	print CSV_OUT "\n";
	print CSV_OUT "\"";
    }
}

# close the .csv file
close CSV_OUT;
close $file_handle;

print "Delimiting and saving the file as csv...\n\n";

# the last line was an end tag and will have an appended 
# newline character and " that need to be removed; this stores
# the file as an array and remove the last line
tie (@File, 'Tie::File', $delimited_file);
splice (@File, -1, 1);
untie @File;

system("rm $file_out");
system("rm $file_out_csv");
system("mv $delimited_file ~/allConnect_stuff/allConnect_Parsed_Logs/");

# DONE! Our log file is now a proper csv file! #
print "Log file successfully converted to csv format!\n\n";
