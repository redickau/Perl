#!/usr/bin/perl
use warnings;
use autodie;
use Path::Class;
use Tie::File;
use IO::File;
use feature 'switch';
use FileHandle;

# create file variable and a pointer to it
my $file = file("$ARGV[0]");
my $file_handle = $file->openr();

my $file_name = $file;
$file_name =~ s{.*/}{};
$file_name =~ s{\.[^.]+$}{};

my $api_dir = $file_name."_APIs";
my $api_path = "allConnect_APIs/$api_dir";
system("mkdir -p $api_path");

# list of patterns to match representing the beginning of a new request
my @custRequestPatterns = (
    qr/^\"<customerManagementRequestResponse/
    );

my @orderRequestPatterns = (
    qr/^\"<orderManagementRequestResponse/
    );

# list of patterns to match representing the end of the current request
my @endPatterns = (
    qr/^<\/customerManagementRequestResponse>\"$/,
    qr/^<\/orderManagementRequestResponse>\"$/
    );

# list of patterns to match the transaction type of the current request
my @transactionTypePatterns = (
    qr/<transactionType>[\w]+<\/transactionType>$/
    );

# create a temp output file
my $cust_out_file = file("CUSTOMER_SERVER_LOG");
my $order_out_file = file("ORDER_SERVER_LOG");

# create a flag that determines when we write to a new file, set write flag to false
my $write_flag = 0;

# open the temp file for writing/overwriting
open(CUST_OUT_FILE, '>'.$cust_out_file);
open(ORDER_OUT_FILE, '>'.$order_out_file);

# iterate through the parsed log file line by line writing certain lines to a new file
while( my $line = $file_handle->getline() ) {

    # if the current line matches a RequestPattern update the flag 
    # so that we continue writing to the appropriate file
    if ($line ~~ @custRequestPatterns) {
        $write_flag = 1;
    }

    if ($line ~~ @orderRequestPatterns) {
        $write_flag = 2;
    }

    # print to the appropriate file based on the value of the flag
    if ($write_flag == 1) {
	print CUST_OUT_FILE "$line";
    }
    
    if ($write_flag == 2) {
	print ORDER_OUT_FILE "$line";
    }
   
    # if the current line matches an endPattern update 
    # the flag so we don't write anything else since this is the end of the request
    if ($line ~~ @endPatterns) {
	$write_flag = 0;
    }
}

close CUST_OUT_FILE;
close ORDER_OUT_FILE;

# create file variable and a pointer to it
$file = file("CUSTOMER_SERVER_LOG");
$file_handle = $file->openr();

my @transactions;

my $cust_submit_file = file("cust_submit_file.csv");
my $customerById_file = file("get_cust_by_id.csv");
my $updateLineItem_file = file("update_line_item.csv");
my $createCustomer_file = file("create_customer.csv");

my $submit_out_fh = FileHandle->new;
my $line_item_out_fh = FileHandle->new;
my $create_cust_out_fh = FileHandle->new;
my $cust_byid_out_fh = FileHandle->new;

my $order_submit_file = file("order_submit_file.csv");
my $orderById_file = file("get_order_by_id.csv");
my $orderUpdateLineItem_file = file("update_order_line_item.csv");
my $createOrder_file = file("create_order.csv");

my $order_submit_out_fh = FileHandle->new;
my $order_line_item_out_fh = FileHandle->new;
my $order_cust_out_fh = FileHandle->new;
my $order_byid_out_fh = FileHandle->new;

my $temp_out = file($file.".tmp");
my $temp_out_fh = FileHandle->new;
open ($temp_out_fh, ">", $temp_out);

# initialize flags for position and writing
$write_flag = 0;

# iterate through the parsed log file line by line writing certain lines to a new file
while( my $line = $file_handle->getline() ) {

    if ($line ~~ @transactionTypePatterns) {
	@transactions = split(/>/, $line);
	
	given ($transactions[1]) {
	    when (/submit/) {
		$write_flag = 1;

		close $temp_out_fh;
		$temp_out_fh = $temp_out->openr();
		open($submit_out_fh, ">>", $cust_submit_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $submit_out_fh $tmp_line;
		}
		print $submit_out_fh "$line";
		close $submit_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    when (/getCustomerById/) {
		$write_flag = 2;

		close $temp_out_fh;
    		$temp_out_fh = $temp_out->openr();
		open($cust_byid_out_fh, ">>", $customerById_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $cust_byid_out_fh $tmp_line;
		}
		print $cust_byid_out_fh "$line";
		close $cust_byid_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    when (/updateLineItem(Status)?/) {
		$write_flag = 3;

		close $temp_out_fh;
		$temp_out_fh = $temp_out->openr();
		open($line_item_out_fh, ">>", $updateLineItem_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $line_item_out_fh $tmp_line;
		}
		print $line_item_out_fh $line;
		close $line_item_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    when (/createCustomer/) {
		$write_flag = 4;

		close $temp_out_fh;
		$temp_out_fh = $temp_out->openr();
		open($create_cust_out_fh, ">>", $createCustomer_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $create_cust_out_fh $tmp_line;
		}
		print $create_cust_out_fh $line;
		close $create_cust_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    default {
		$write_flag = 0;
	    }
	}
    }
    elsif ($write_flag == 1) {
	open($submit_out_fh, ">>", $cust_submit_file);
	print $submit_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}
	close $submit_out_fh;
    }
    elsif ($write_flag == 2) {
	open($cust_byid_out_fh, ">>", $customerById_file);
	print $cust_byid_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}
	close $cust_byid_out_fh;
    }
    elsif ($write_flag == 3) {
	open($line_item_out_fh, ">>", $updateLineItem_file);
	print $line_item_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}
	close $line_item_out_fh;
    }
    elsif ($write_flag == 4) {
	open($create_cust_out_fh, ">>", $createCustomer_file);
	print $create_cust_out_fh $line;

	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}	
	close $create_cust_out_fh;
    }
    else {
	print $temp_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    close $temp_out_fh;
	    open ($temp_out_fh, ">", $temp_out);
	}
    }
}

close $file_handle;
close $temp_out_fh;

$file = file("ORDER_SERVER_LOG");
$file_handle = $file->openr();

$write_flag = 0;

$temp_out = file($file.".tmp");
open ($temp_out_fh, ">", $temp_out);

# iterate through the parsed log file line by line writing certain lines to a new file
while( my $line = $file_handle->getline() ) {

    if ($line ~~ @transactionTypePatterns) {
	@transactions = split(/>/, $line);
	
	given ($transactions[1]) {
	    when (/submit/) {
		$write_flag = 1;

		close $temp_out_fh;
		$temp_out_fh = $temp_out->openr();
		open($order_submit_out_fh, ">>", $order_submit_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $order_submit_out_fh $tmp_line;
		}
		print $order_submit_out_fh "$line";
		close $order_submit_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    when (/getOrderById/) {
		$write_flag = 2;

		close $temp_out_fh;
    		$temp_out_fh = $temp_out->openr();
		open($order_byid_out_fh, ">>", $orderById_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $order_byid_out_fh $tmp_line;
		}
		print $order_byid_out_fh "$line";
		close $order_byid_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    when (/updateLineItem(Status)?/) {
		$write_flag = 3;

		close $temp_out_fh;
		$temp_out_fh = $temp_out->openr();
		open($order_line_item_out_fh, ">>", $orderUpdateLineItem_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $order_line_item_out_fh $tmp_line;
		}
		print $order_line_item_out_fh $line;
		close $order_line_item_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    when (/createOrder/) {
		$write_flag = 4;

		close $temp_out_fh;
		$temp_out_fh = $temp_out->openr();
		open($create_order_out_fh, ">>", $createOrder_file);

		while( my $tmp_line = $temp_out_fh->getline() ) {
		    print $create_order_out_fh $tmp_line;
		}
		print $create_order_out_fh $line;
		close $create_order_out_fh;

		close $temp_out_fh;
		open($temp_out_fh, ">", $temp_out);
	    }
	    default {
		$write_flag = 0;
	    }
	}
    }
    elsif ($write_flag == 1) {
	open($order_submit_out_fh, ">>", $order_submit_file);
	print $order_submit_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}
	close $order_submit_out_fh;
    }
    elsif ($write_flag == 2) {
	open($order_byid_out_fh, ">>", $orderById_file);
	print $order_byid_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}
	close $order_byid_out_fh;
    }
    elsif ($write_flag == 3) {
	open($order_line_item_out_fh, ">>", $orderUpdateLineItem_file);
	print $order_line_item_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}
	close $order_line_item_out_fh;
    }
    elsif ($write_flag == 4) {
	open($create_order_out_fh, ">>", $createOrder_file);
	print $create_order_out_fh $line;

	if ($line ~~ @endPatterns) {
	    $write_flag = 0;
	}	
	close $create_order_out_fh;
    }
    else {
	print $temp_out_fh $line;
	
	if ($line ~~ @endPatterns) {
	    close $temp_out_fh;
	    open ($temp_out_fh, ">", $temp_out);
	}
    }
}

close $file_handle;
close $temp_out_fh;

system("rm -f CUSTOMER_SERVER_*");
system("rm -f ORDER_SERVER_*");
system("mv *.csv $api_path");
