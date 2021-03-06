#!/usr/bin/perl

#use warnings 'all';
#use strict;
#use FindBin;
#use Math::Round;

use verilog::gen;

my $scriptInfo = 
    "/*------------------------------------------------------------------------------\n" .
    " * This code was generated by Spiral IIR Filter Generator, www.spiral.net\n" .
    " * Copyright (c) 2006, Carnegie Mellon University\n" .
    " * All rights reserved.\n" .
    " * The code is distributed under a BSD style license\n" .
    " * (see http://www.opensource.org/licenses/bsd-license.php)\n" .
    " *------------------------------------------------------------------------------" .
    " */\n";

#-----------------------------------------------------------------------
# @brief Calls multBlockGen.pl on the commandline and generates the
#   multiply block
# @param fh file handle to print to, pass with \*FH
# @param option "vanilla" - base or "addChain" - optimized
# @param moduleName multiply block module name
# @param ports hash of port names: \{i_data => "in", o_data => "out"}
# @param bitwidth input bitwidth to multiplier block
# @param fixedPoint how many bits of data are below the decimal point,
# @param constants array of constants
# @return undef
#-----------------------------------------------------------------------
sub genMultiply {
    my ($fh, $option, $moduleName, $bitwidth, $fixedPoint, $constants, $debug) = @_;
    
    my $mult_cmd = "./multBlockGen.pl";
    
    my $constantCount = scalar(@$constants);

    for(my $i = 0; $i < $constantCount; $i++){
	$mult_cmd .= " " . $constants->[$i];
    }
    
    if($option eq "addChain"){
	$mult_cmd .= " -addChain";
    }
    elsif($option eq "base"){
	$mult_cmd .= " -base";
    }
    else{
	print STDERR "./iirGen.pl: genMultiply doesn't know how to handle option: $option\n";
	exit(-2);
    }
    
    $mult_cmd .= " -suppressInfo" .
	" -moduleName $moduleName" .
	" -bitWidth $bitwidth" .
	" -fractionalBits $fixedPoint" .
	" -inData X " .
	" -outData Y " .
	" -debug ";
    
    if(!open(MULT_OUT, "$mult_cmd |")){
	print STDERR "Error executing multBlockGen.pl\n";
	exit(-2);
    }
    
    my $multBlockSize;

    my %outputBitwidths = ();
    
    if($option eq "addChain"){
	while(my $line = <MULT_OUT>){
	    chomp $line;

	    if($constantCount > 1){
		#assign Y[0] = w109[30:15];    //BitwidthUsed (0, 7)
		if($line =~ /assign \w+\[(\d+)\].+\/\/BitwidthUsed\((.*)\)/){
		    my $index = $1;
		    my $values = $2;
		    if($values eq "none"){
			my @info = (0,0,0);
			$outputBitwidths{$index} = \@info;
		    }else{
			if($values=~ /^(\d+), (\d+)$/){
			    my @info = (1,$1,$2);
			    $outputBitwidths{$index} = \@info;
			}else{
			    print $fh "doesn't look right: $line\n";
			    exit(-2);
			}
			
		    }
		}
		elsif($line =~ /MultiplyBlock[a-zA-Z0-9_]+\s+area estimate\s*=\s*([\d\.]+);/){
		    $multBlockSize = getnum($1);
		}
	    }else{
		#assign Y[0] = w109[30:15];    //BitwidthUsed (0, 7)
		if($line =~ /assign .+\/\/BitwidthUsed\(([\d, ]+)\)/){
		    my $index = 0;
		    my $values = $1;
		    if($values eq "none"){
			my @info = (0,0,0);
			$outputBitwidths{$index} = \@info;
		    }else{
			if($values=~ /^(\d+), (\d+)$/){
			    my @info = (1,$1,$2);
			    $outputBitwidths{$index} = \@info;
			}else{
			    print $fh "doesn't look right: $line\n";
			    exit(-2);
			}
			
		    }
		}
		elsif($line =~ /MultiplyBlock[a-zA-Z0-9_]+\s+area estimate\s*=\s*([\d\.]+);/){
		    $multBlockSize = getnum($1);
		}
	    }
	    
	    if(!$debug){
		$line =~ s/;.*\/\/.*$/;/;
	    }
	    print $fh $line . "\n";

	}
    }else{
	while(my $line = <MULT_OUT>){
	    print $fh $line;
	}
    }
    
    
    if(!close(MULT_OUT)){ #check exit code
	print STDERR "Error executing multBlockGen.pl: nonzero exit code\n";
	exit(-2);
    }
    
    print $fh "\n\n";

    return ($multBlockSize, \%outputBitwidths);
}

#-----------------------------------------------------------------------
# @brief Calls firGen.pl on the commandline and generates the
#   FIR block
# @param fh file handle to print to, pass with \*FH
# @param option "vanilla" - base or "addChain" - optimized
# @param moduleName multiply block module name
# @param bitwidth input bitwidth to multiplier block
# @param fixedPoint how many bits of data are below the decimal point,
# @param constants array of constants
# @return undef
#-----------------------------------------------------------------------
sub genFIR {
    my ($fh, $option, $moduleName, $bitwidth, $fixedPoint, $constants, $reset, $reset_edge, $debug) = @_;
    
    my $firgen_cmd = "./firGen.pl";
    
    my $constantCount = scalar(@$constants);

    for(my $i = 0; $i < $constantCount; $i++){
	$firgen_cmd .= " " . $constants->[$i];
    }

    if($option eq "addChain"){
	$firgen_cmd .= " -addChain";
    }
    elsif($option eq "base"){
	$firgen_cmd .= " -base";
    }
    else{
	print STDERR "./iirGen.pl: genFIR doesn't know how to handle option: $option\n";
	exit(-2);
    }
    
    $firgen_cmd .= " -suppressInfo" .
	" -moduleName $moduleName" .
	" -bitWidth $bitwidth" .
	" -fractionalBits $fixedPoint" .
	" -inData X " .
	" -outData Y " .
	" -clk clk " .
	" -outReg " .
	" -reset $reset " .
	" -reset_edge $reset_edge ";
    
    $firgen_cmd .= " -debug "  if($debug);
    
    if(!open(FIR_OUT, "$firgen_cmd |")){
	print STDERR "Error executing: $firgen_cmd\n";
	exit(-2);
    }
   
    my $firBlockSize = 0;
    
    if($option eq "addChain"){
	while(my $line = <FIR_OUT>){
	    chomp $line;
	    
	    if($line =~ /\/\/(.*) area estimate\s*=\s*([\d\.]+);/){
		if($1 eq $moduleName){
		    $firBlockSize = getnum($2);
		}
	    }

	    print $fh $line . "\n";
	}
    }else{
	while(my $line = <FIR_OUT>){
	    print $fh $line;
	}
    }
    
    if(!close(FIR_OUT)){ #check exit code
	print STDERR "Error executing (nonzero exit code): $firgen_cmd\n";
	exit(-2);
    }
    
    print $fh "\n\n";
    
    return $firBlockSize;
}

#-----------------------------------------------------------------------
# @brief Generates code for IIR filter
# @param fh file handle to print to, pass with \*FH
# @param ports hash of port names: {i_data => "in", o_data => "out", clk => "clk", reset => "rst_n"}
# @param bitWidth input bitwidth to multiplier block
# @param firLeftName input side of the fir
# @param firRightName output side of the fir
# @return undef
#-----------------------------------------------------------------------
sub genIIR{
    my ($fh, $ports, $bitwidth, $firLeftName, $firRightName, $debug) = @_;
    
    my $leftOut = "leftOut";
    my $rightOut = "rightOut";
    
    print $fh "  wire [" . ($bitwidth - 1) . ":0] $leftOut, $rightOut;\n\n";
    
    print $fh "  $firLeftName my_$firLeftName(\n" .
	"    .X(" . $ports->{i_data} . "),\n" .
	"    .Y(" . $leftOut . "),\n" .
	"    .clk(" . $ports->{clk} . "),\n" .
	"    ." . $ports->{reset} . "(" . $ports->{reset} . ")\n" .
	");\n\n";
    
    print $fh "  $firRightName my_$firRightName(\n" .
	"    .X(" . $ports->{o_data} . "),\n" .
	"    .Y(" . $rightOut . "),\n" .
	"    .clk(" . $ports->{clk} . "),\n" .
	"    ." . $ports->{reset} . "(" . $ports->{reset} . ")\n" .
	");\n\n";

    print $fh "  assign " . $ports->{o_data} . " = $leftOut + $rightOut;";
    print $fh " // adder($bitwidth)" if($debug);
    print $fh "\n\n";
    
    return adderArea($bitwidth);
}

#$iirSize += genIIRform2($fh, \%regPorts, $bitWidth, $multName . "_left", $multName . "_right", \@leftConstants, $outputHashLeft, \@rightConstants, $outputHashRight, $debug);
#-----------------------------------------------------------------------
# @brief Generates code for FIR filter
# @param fh file handle to print to, pass with \*FH
# @param ports hash of port names: \{i_data => "in", o_data => "out", clk => "clk"}
# @param bitWidth input bitwidth to multiplier block
# @param multiplyName multiply block module name
# @param fixedPoint how many bits of data are below the decimal point
# @param constantCount array of constants
# @return undef
#-----------------------------------------------------------------------
sub genIIRform2{
    my ($fh, $ports, $bitwidth, $multiplyName_left, $multiplyName_right, $leftConst, $left_outputBitwidths, $rightConst, $right_outputBitwidths, $reset_edge, $debug) = @_;
    
    my $multOut = "multProducts";
    
    my $left_constantCount = scalar(@$leftConst);
    my $right_constantCount = scalar(@$rightConst);

    #multOut wires
    print $fh "  wire [" . ($bitwidth - 1) . ":0] ${multOut}_left";
    print $fh " [0:" . ($left_constantCount - 1) . "]" if($left_constantCount > 1);
    print $fh ";\n\n";
    print $fh "  wire [" . ($bitwidth - 1) . ":0] ${multOut}_right";
    print $fh " [0:" . ($right_constantCount - 1) . "]" if($right_constantCount > 1);
    print $fh ";\n\n";
    
    print $fh "  $multiplyName_left my_$multiplyName_left(\n"
	. "    .X(" . $ports->{i_data} . ")";
    
    if($left_constantCount > 1){
	for(my $i = 0; $i < $left_constantCount; $i++){
	    print $fh ",\n    .Y" . ($i + 1) .
		"(${multOut}_left\[$i\])";
	}
    }
    else{
	print $fh ",\n    .Y" . 
	    "(${multOut}_left)"; 
    }
    
    print $fh "\n  );\n\n";

    print $fh "  $multiplyName_right my_$multiplyName_right(\n"
	. "    .X(" . $ports->{o_data_next} . ")";
    
    if($right_constantCount > 1){
	for(my $i = 0; $i < $right_constantCount; $i++){
	    print $fh ",\n    .Y" . ($i + 1) .
		"(${multOut}_right\[$i\])";
	}
    }
    else{
	print $fh ",\n    .Y" . 
	    "(${multOut}_right)"; 
    }
    
    print $fh "\n  );\n\n";
    
    my $maxConst = 0;
    my $diff = 0;
    my $max = "";
    my $min = "";

    if($left_constantCount > $right_constantCount){
	$maxConst = $left_constantCount;
	$diff = $left_constantCount - $right_constantCount;
	$max = "_left";
	$min = "_right";
    }else{
	$maxConst = $right_constantCount;
	$diff = $right_constantCount - $left_constantCount;
	$max = "_right";
	$min = "_left";
    }

    my $diff2 = $diff;
    
    #always block
    my $arrayName = "iirStep";
    if($maxConst > 1){
	print $fh "  reg [" . ($bitwidth-1) . ":0] $arrayName";
	if ($maxConst > 2){
	    print $fh "[0:" . ($maxConst-2) . "]";
	}
    }
    
    print $fh ";\n\n";
    
    my $resetSense = "";
    my $addedPrefix = "";
    if(defined($reset_edge)){
	$resetSense = " or $reset_edge " . $ports->{"reset"};
	$addedPrefix = "  ";
    }

    my $areaSum = 0;
    
    if($maxConst > 1){
	print $fh "  always@(posedge ". $ports->{"clk"} . $resetSense . ") begin\n";;
	if(defined($reset_edge)){
	    print $fh "    if(~" . $ports->{"reset"} . ") begin\n";
	    print $fh "      ${arrayName}";
	    print $fh "\[0\]" if($maxConst > 2);
	    print $fh " <= " . toHex(0, $bitwidth) . ";\n";
	    
	    for(my $i = 1; $i < $maxConst - 1; $i++){
		my $index = $i - 1;
		print $fh "      ${arrayName}\[$i\] <= ". toHex(0, $bitwidth) .";\n";
	    }
	    print $fh "    end\n";
	    print $fh "    else begin\n";
	}
    
	print $fh $addedPrefix . "    ${arrayName}";
	print $fh "\[0\]" if($maxConst > 2);
	print $fh " <=  ";
	
	if($diff2){
	    print $fh "${multOut}${max}[0];";
	    my $flopSize = flopArea($bitwidth, defined($reset_edge));
	    print $fh " // $flopSize = flop(0, $bitwidth - 1)" if($debug);
	    print $fh "\n";
	    $diff2--;
	    $areaSum += $flopSize;
	}
	else{
	    print $fh "${multOut}_left[0] + ${multOut}_right[0];";
	    my $areaLocal =  adderArea($bitwidth) + flopArea($bitwidth, defined($reset_edge));
	    print $fh " // $areaLocal = adder($bitwidth) + flop(0, $bitwidth - 1)" if($debug);
	    print $fh "\n";
	    $areaSum += $areaLocal;
        }
	
	for(my $i = 1; $i < $maxConst - 1; $i++){
	    my $index = $i - 1;
	    my $index2 = $i;
	    
	    my $flopSize = flopArea($bitwidth, defined($reset_edge));
	    
	    if($diff2){
		print $fh $addedPrefix . "    ${arrayName}\[$index2\] <=  ${arrayName}\[$index\] + ${multOut}${max}\[$index2\];";
		my $addsize = adderArea($bitwidth) + $flopSize;
		print $fh " // $addsize = adder($bitwidth) + flop(0, $bitwidth - 1)" if($debug);
		print $fh "\n";
		$diff2--;
		$areaSum += $addsize;
	    }else{
		my $index3 = $i - $diff;
		print $fh $addedPrefix . "    ${arrayName}\[$index2\] <=  ${arrayName}\[$index\] + ${multOut}${max}\[$index2\] + ${multOut}${min}\[$index3\];";
		my $addsize = 2*adderArea($bitwidth) + $flopSize;
		print $fh " // $addsize = 2*adder($bitwidth) + flop(0, $bitwidth - 1)" if($debug);
		print $fh "\n";
		$areaSum += $addsize;
	    }
	}
	
	print $fh "    end\n" if(defined($reset_edge));
	print $fh "  end\n\n";
	
    }
    
    if($maxConst > 1){
	print $fh "  assign " . $ports->{o_data} . " = ${arrayName}";
	print $fh "[". ($maxConst - 2) . "\]" if ($maxConst > 2);
	print $fh "+ ${multOut}${max}\[". ($maxConst - 1) ."\]";
	my $index3 = $maxConst - $diff-1;
	print $fh "+ ${multOut}${min}";

	print $fh "\[$index3\];" if($maxConst - $diff > 1);
	
	my $addsize = 2*adderArea($bitwidth);
	print $fh " // $addsize = 2*adder($bitwidth)" if($debug);
	print $fh "\n";
	$areaSum += $addsize;
    }else{ #$constantCount == 1
	print $fh "  assign " . $ports->{o_data} . " = ${multOut}${max} + ${multOut}${min};\n";
    }
    print $fh "\n";
    
    return $areaSum;
}

#-----------------------------------------------------------------------
# @brief generates a testBench, which provides the filter with an impulse
#  and, if all goes correct, should return a time reversed reading of the
#  filter
#-----------------------------------------------------------------------
sub genTestBench{
    my ($fh, $ports, $moduleList, $bitwidth, $filterSteps, $registerDelays, $fixedPoint, $reset_edge, $constants) = @_;
    
   
    print STDERR "Test Bench Option not supported.\n";
    exit(-2);


    print $fh "  integer testEndedGracefully;\n\n";

    print $fh "  reg [" . ($bitwidth - 1) . ":0] inData;\n".
	"  reg clk;\n";
    
    my $verify;
    
    if(!scalar(@$moduleList)){
	print STDERR "Error: Cannot write a testBench for no modules.\n";
	exit(-2);
    }
    
    foreach my $module(@$moduleList){
	print $fh
	    "  wire  [" . ($bitwidth - 1) . ":0] ${module}_out;\n" .
	    "  integer ${module}_val;\n";
    }
    
    print $fh "\n";
    
    print $fh
	"  initial begin\n";
    
    print $fh "    \$display(\"                   Time, ". join("_val, ", @$moduleList) . "_val\");\n";
    
    print $fh
	"    clk = 1;\n".
	"    forever \#1 clk =~clk;\n".
	"  end\n\n";
    
    foreach my $module(@$moduleList){
	print  $fh
	    "  ${module} my_${module}(\n".
	    "    ." . $ports->{"clk"} ."(clk),\n".
	    "    ." . $ports->{"i_data"} ."(inData),\n".
	    "    ." . $ports->{"o_data"} ."(${module}_out)\n".
	    "  );\n\n";
    }
    
    

    my $pr_str = "\$display(\"Output: \%d";
    foreach my $module(@$moduleList){
	$pr_str .= ", %d";
    }
    $pr_str .= "\", \$time";
    foreach my $module(@$moduleList){
	$pr_str .= ", ${module}_val";
    }
    $pr_str .= ");\n";
    
    print $fh "\n  //Convert unsigned values to signed integers for comparison\n";
    foreach my $module(@$moduleList){
	print  $fh
	    "  always@(${module}_out) begin\n" .
	    "    if(${module}_out >= ".(1 << ($bitwidth - 1)).")\n" .
	    "      ${module}_val = ${module}_out - ".(1 << $bitwidth).";\n" .
	    "    else\n" .
	    "      ${module}_val = ${module}_out;\n" .
	    "  end\n\n";
    }
    
    print $fh
	"  initial begin\n" . 
        "    //ignore initial x's and initial\n" .
        "    //delays through registers\n" .
	"    #". (2*($filterSteps + 3*$registerDelays)) .";\n";
    
    for(my $i = scalar(@$constants) - 1; $i >= 0; $i--){
	my $const = $constants->[$i];
	print $fh
	    "\n    @(posedge clk);\n" .
	    "      #0;\n" .
	    "      $pr_str";
	
	foreach my $module(@$moduleList){
	    print $fh
		"      if(($const+1 <= ${module}_val) && (${module}_val <= $const+1))\n" .
		"        \$display(\"ERROR: ${module}_val should be $const\");\n";
	}
    }

    print $fh
	"\n    //All outputs have been seen\n" .
	"    testEndedGracefully <= 1;\n\n";
    
    print $fh
	"\n    forever @(posedge clk) begin\n" .
	"      #0;\n";
    foreach my $module(@$moduleList){
	print $fh
	    "      if(${module}_val !== 0 )\n" .
	    "        \$display(\"ERROR: ${module}_val should be 0\");\n";
    }

    print $fh
	"    end //always@(posedge clk)\n\n".
	"  end //initial begin\n\n";

    print  $fh
	"  initial begin\n".
	"    testEndedGracefully <= 0;\n" .
	"    inData <= 0;\n".
        "    #". (2*($filterSteps + $registerDelays)) .";\n".
	"    //feed an impulse\n" .
	"    inData <=  1 << $fixedPoint;\n".
	"    #2;\n".
	"    inData <= 0;\n".
	"    #". (2*$filterSteps + 10) .";\n".
        "    if(testEndedGracefully !== 1)\n" .
        "      \$display(\"ERROR: Test ended too soon.  Not all outputs seen.\");\n" .
        "    \$stop;\n".
        "    \$finish;\n".
        "  end\n\n";
}

#-----------------------------------------------------------------------
# @brief puts it all together, reading input, etc
#-----------------------------------------------------------------------
sub main {

    #cmdline args = defaults:
    my @leftConstants = ();
    my @rightConstants = ();
    my $bitWidth = 32;
    my $fixedPoint = 0;
    my $moduleName = "iirFilter";
    my $inReg = 0;
    my $outReg = 0;
    my $nonOptimal = 0;
    my $optimal = 0;
    my $testBench = 0;
    my $testBenchName = "top";
    my $outFileName = undef;
    my $reset_edge = undef;
    my $fh;
    my $suppressInfo;
    my $debug = 0;
    my $filterForm = 1;
    my %ports = 
	("i_data" => "i_data",
	 "o_data" => "o_data",
	 "clk" => "clk");

    my $cmdLine = "./iirGen.pl " . join(" ", @ARGV);
    
    #my args
    my $parseConstants = undef;
    
    #parse args
    for(my $i = 0; $i < scalar(@ARGV); $i++){
	
	if($ARGV[$i] eq ""){
	    next;
	}
	elsif($ARGV[$i] eq "-B"){
	    $parseConstants = \@leftConstants;
	}
	elsif($ARGV[$i] eq "-A"){
	    $parseConstants = \@rightConstants;
	}
	elsif($ARGV[$i] eq "-debug"){
	    $debug = 1;
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-filterForm"){
	    $i++;
	    $filterForm = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-moduleName"){
	    $i++;
	    $moduleName = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-bitWidth"){
	    $i++;
	    $bitWidth = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-fractionalBits"){
	    $i++;
	    $fixedPoint = $ARGV[$i];
	    $parseConstants = undef;
	    if($fixedPoint < 0){
		print STDERR "Fractional bits argument must be non-negative: $ARGV[$i]\n";
		printUsage();
	    }
	}
	elsif($ARGV[$i] eq "-reset_edge"){
	    $i++;
	    $reset_edge = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-reset"){
	    $i++;
	    $ports{"reset"} = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-inData"){
	    $i++;
	    $ports{"i_data"} = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-inReg"){
	    $inReg = 1;
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-outData"){
	    $i++;
	    $ports{"o_data"} = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-outReg"){
	    $outReg = 1;
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-clk"){
	    $i++;
	    $ports{"clk"} = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-h" || $ARGV[$i] eq "--help"){
	    printUsage();
	}
	elsif($ARGV[$i] eq "-base"){
	    $nonOptimal = 1;
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-addChain"){
	    $optimal = 1;
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-testBench"){
	    $testBench = 1;
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-testBenchName"){
	    $i++;
	    $testBench = 1;
	    $testBenchName = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-outFile"){
	    $i++;
	    $outFileName = $ARGV[$i];
	    $parseConstants = undef;
	}
	elsif($ARGV[$i] eq "-suppressInfo"){
	    $suppressInfo = 1;
	    $parseConstants = undef;
	}
	elsif(defined($parseConstants)){
	    #verify we were given a number:
	    my $temp = getnum($ARGV[$i]);
	    if(defined(scalar($temp))){
		push(@$parseConstants, $ARGV[$i]);
	    }
	    else{
		print STDERR "UNDEFINED ARG: " . $ARGV[$i] . "\n";
		printUsage();
	    }
	}
	else{
	    print STDERR "UNDEFINED ARG: " . $ARGV[$i] . "\n";
	    printUsage();
	}
    }
    
    if(!defined($reset_edge)){
	$reset_edge = "negedge";
    }
    
    my $warnOpt = 0;

    if(scalar(@rightConstants)){
	my $a = shift(@rightConstants);
	if($a != 1 << $fixedPoint){
	    $warnOpt = 1; #TODO: scale
	    print STDERR "The first constant in A is required to be 1, please check the input and try again.\n";
	    printUsage();
	}
    }
    else{
	print STDERR "A(0) constants is required and must be 1.\n";
	printUsage();
    }

    my $rightFir = 0;
    my $leftFir = 0;

    $rightFir = 1 if(scalar(@rightConstants));
    $leftFir = 1 if(scalar(@leftConstants));

    if(!($rightFir && $leftFir)){
	print STDERR "Both A constants and B constants are required, please check in the input and try again.\n";
	printUsage();
    }

    #right filter (A) must be negatized to use an adder
    for(my $i = 0; $i < scalar(@rightConstants); $i++){
	$rightConstants[$i] = -1 * $rightConstants[$i];
    }
    
    if(defined($reset_edge)){
	if($reset_edge eq "negedge"){
	    if(!defined($ports{"reset"})){
		$ports{"reset"} = "rst_n";
	    }
	}
	elsif($reset_edge eq "posedge"){
	    if(!defined($ports{"reset"})){
		$ports{"reset"} = "rst";
	    }
	}
	else{
	    print STDERR "Invalid reset_edge: $reset_edge\n";
	    printUsage();
	}
    }

    if(defined($outFileName)){
	if(!open(OUTFILE, "> $outFileName")){
	    print STDERR "Unable to open outfile for writing: $outFileName\n";
	    exit(-2);
	}
	$fh = \*OUTFILE;
    }
    else{
	$fh = \*STDOUT;
    }

    #ports
    my @portList = (["input  ", $ports{"i_data"}, $bitWidth],
		    ["input  ", $ports{"clk"}],
		    ["output ", $ports{"o_data"}, $bitWidth],
		    ["input  ", $ports{"reset"}]);
    
    my $optSuffix = "";
    my $vanillaSuffix = "";
    if($optimal && $nonOptimal){
	$optSuffix = "_addChain";
	$vanillaSuffix = "_base";
    }
    elsif(!($optimal || $nonOptimal)){
	$optimal = 1; #default
    }

    unless($suppressInfo){
	print $fh $scriptInfo;
	print $fh "/* $cmdLine */\n";
    }

    if($warnOpt){
	print $fh "/* A(0) not equal to 1 << fractionalBits, scaling all taps to match. */\n";
    }

    #registered ports:
    my %regPorts = %ports;

    $regPorts{"i_data"} = $ports{"i_data"} . "_in" if($inReg);
    $regPorts{"o_data"} = $ports{"o_data"} . "_in" if($outReg);
    
    if($outReg){
	$regPorts{"o_data_next"} = $ports{"o_data"};
    }else{
	$regPorts{"o_data_next"} = $ports{"o_data"} . "_next";
    }
    

    my $prefix = "w";

    #inRegList:($inWire, $inReg, $bitWidth)
    my @inRegList = ([$ports{"i_data"}, $regPorts{"i_data"}, $bitWidth]);

    #outRegList:($outReg, $outWire, $bitWidth)

    my @outRegList = ([$regPorts{"o_data_next"}, $regPorts{"o_data"}, $bitWidth]);
	
    if($filterForm == 1){
	if($optimal){
	    my $firName = $moduleName . $optSuffix . "_firBlock";
	    
	    #fir blocks are separate modules
	    my $iirSize = genFIR($fh, "addChain", $firName . "_left", $bitWidth, $fixedPoint, \@leftConstants, $ports{"reset"}, $reset_edge, $debug);
	    $iirSize += genFIR($fh, "addChain", $firName . "_right", $bitWidth, $fixedPoint, \@rightConstants, $ports{"reset"}, $reset_edge, $debug);
	    
	    genHeader($fh, $moduleName . $optSuffix, \@portList);
	    
	    $iirSize += registerIn($fh, \@inRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($inReg);
	    $iirSize += registerOut($fh, \@outRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($outReg);
	    
	    $iirSize += genIIR($fh, \%regPorts, $bitWidth, $firName . "_left", $firName . "_right", $debug);
	    genTail($fh, $moduleName . $optSuffix, $iirSize);
	}
	if($nonOptimal){
	    my $firName = $moduleName . $vanillaSuffix . "_firBlock";
	    
	    genFIR($fh, "base", $firName . "_left", $bitWidth, $fixedPoint, \@leftConstants, $ports{"reset"}, $reset_edge);
	    genFIR($fh, "base", $firName . "_right", $bitWidth, $fixedPoint, \@rightConstants, $ports{"reset"}, $reset_edge);
	    
	    genHeader($fh, $moduleName . $vanillaSuffix, \@portList);
	    registerIn($fh, \@inRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($inReg);
	    registerOut($fh, \@outRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($outReg);
	    genIIR($fh, \%regPorts, $bitWidth, $firName . "_left", $firName . "_right");
	    genTail($fh, $moduleName . $vanillaSuffix);
	}
    }else{
	if($optimal){
	    @leftConstants = reverse @leftConstants;
	    @rightConstants = reverse @rightConstants;

	    my $multName = $moduleName . $optSuffix . "_MultiplyBlock";
	    
	    my ($multSizeLeft, $outputHashLeft) = genMultiply($fh, "addChain", $multName . "_left", $bitWidth, $fixedPoint, \@leftConstants, $debug);
	    my ($multSizeRight, $outputHashRight) = genMultiply($fh, "addChain", $multName . "_right", $bitWidth, $fixedPoint, \@rightConstants, $debug);

	    my $iirSize = $multSizeLeft + $multSizeRight;
	    
	    genHeader($fh, $moduleName . $optSuffix, \@portList);
	    
	    $iirSize += registerIn($fh, \@inRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($inReg);
	    #we need this register regardless
	    $iirSize += registerOut($fh, \@outRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge);
	    
	    $iirSize += genIIRform2($fh, \%regPorts, $bitWidth, $multName . "_left", $multName . "_right", \@leftConstants, $outputHashLeft, \@rightConstants, $outputHashRight, $reset_edge, $debug);

	    genTail($fh, $moduleName . $optSuffix, $iirSize);
	}
	if($nonOptimal){
	    print STDERR "form II not available to baseline application\n";
	    exit(-1);

	    my $firName = $moduleName . $vanillaSuffix . "_firBlock";
	    
	    genFIR($fh, "base", $firName . "_left", $bitWidth, $fixedPoint, \@leftConstants, $ports{"reset"}, $reset_edge);
	    genFIR($fh, "base", $firName . "_right", $bitWidth, $fixedPoint, \@rightConstants, $ports{"reset"}, $reset_edge);
	    
	    genHeader($fh, $moduleName . $vanillaSuffix, \@portList);
	    registerIn($fh, \@inRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($inReg);
	    registerOut($fh, \@outRegList, $ports{"clk"}, $ports{"reset"}, $reset_edge) if($outReg);
	    genIIR($fh, \%regPorts, $bitWidth, $firName . "_left", $firName . "_right");
	    genTail($fh, $moduleName . $vanillaSuffix);
	}
    }
    if($testBench){
	
	print STDERR "TestBench not written yet.  Sorry.\n";
	exit(-2);
	
	#my @dummy = ();
	#my @moduleList =();
	#push(@moduleList, $moduleName . $optSuffix) if($optimal);
	#push(@moduleList, $moduleName . $vanillaSuffix) if($nonOptimal);
	
	#genHeader($fh, $testBenchName, \@dummy);
        #genTestBench($fh, \%ports, \@moduleList, $bitWidth, scalar(@constants), (($inReg?1:0) + ($outReg?1:0)),  $fixedPoint, $reset_edge, \@constants);
	#genTail($fh, $testBenchName);
    }
    close($fh) if(defined($outFileName));

    return 1;
}

#-----------------------------------------------------------------------
# @brief prints the usage and exits -1
#-----------------------------------------------------------------------
sub printUsage(){
    
    print STDERR <<EOF;

$scriptInfo

  ./iirGen.pl -leftConstants 10 20 30 40 30 20 10 
          -rightConstants 10 20 30 40 30 20 10 [-moduleName iirFilter] [-bitWidth 32]
         [-fractionalBits value] [-inData i_data] [-inReg] [-outData o_data] [-outReg] 
         [-clk clk] [-base] [-addChain] [-testBench | -testBenchName top] [-outFile fileName]
         [-suppressInfo] [-reset wireName] [-reset_edge negedge|posedge]

  -leftConstants: input side of the filter
  -rightConstants: output side of the filter

  -moduleName: verilog module name
  -bitWidth: How many bits of data the multiplier multiplies by
  -fractionalBits: how many bits of data are below the decimal point, default: 0
     when this is used, the constants still need to be whole numbers, merely 
     2^x is now construed to be 1, where x is the fractionalBits value
  -inData: verilog input port name
  -inReg: cleanly register input
  -outData: verilog output port name
  -outReg: cleanly register output
  -clk: verilog clk name
  -reset: wireName for reset wire defaults to rst for posedge and rst_n for negedge
  -reset_edge: use asynchronous reset at negedge or posedge
     if neither reset or reset_edge is provided on the commandline, filter generated
     defaults to negedge
  -base: generate the vanilla, non-optimized version, for comparison
     may be used in conjunction with -addChain, will generate 2 modules 
  -addChain: generate the optimized version, default
     may be used in conjunction with -base, will generate 2 modules
  -testBench: generate testBench
     if used alone or in conjunction with one of the above two options, 
     will generate a test bench to print the inputs and outputs
     based on a pseudo random input stream
 
     if used in conjunction with both -base and -addChain, will
     will generate code to compare the output of the two when run
  -testBenchName: generate testBench with the given name

  -outFile print output to said fileName, defaults to stdout
  -suppressInfo don't tag script info at the beginning of the verilog file

EOF

  exit(-1);
}

if(!main()){
    print STDERR "Script Failed.\n";
    exit(-1);
}
else{
    exit(0);
}

1;