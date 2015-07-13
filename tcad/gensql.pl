#!/usr/bin/perl

# Generate a script to create mysql tables to hold TCAD data and load the data.
# Reads the file format from layout.csv
# layout.csv should be generated by opening
# "Appraisal Export Layout - 8 0 18UPDATED.xlsx" and exporting as csv
# This script may or may not work without modification for any newer version
# of the layout document.

# Exclude a bunch of things that aren't that interesting, so we're under
# mysql's row length limit
$exclude{"prop"}{"sup_action"} = 1;
$exclude{"prop"}{"sup_cd"} = 1;
$exclude{"prop"}{"sup_desc"} = 1;
$exclude{"prop"}{"py_addr_line1"} = 1;
$exclude{"prop"}{"py_addr_line2"} = 1;
$exclude{"prop"}{"py_addr_line3"} = 1;
$exclude{"prop"}{"timber_use"} = 1;
$exclude{"prop"}{"timber_market"} = 1;
$exclude{"prop"}{"deed_book_id"} = 1;
$exclude{"prop"}{"deed_book_page"} = 1;
$exclude{"prop"}{"mortgage_co"} = 1;
$exclude{"prop"}{"mortgage_co_name"} = 1;
$exclude{"prop"}{"mortgage_acct_id"} = 1;
$exclude{"prop"}{"ex_prorate_begin"} = 1;
$exclude{"prop"}{"ex_prorate_end"} = 1;
$exclude{"prop"}{"entity_agent_id"} = 1;
$exclude{"prop"}{"entity_agent_name"} = 1;
$exclude{"prop"}{"entity_agent_addr_line1"} = 1;
$exclude{"prop"}{"entity_agent_addr_line2"} = 1;
$exclude{"prop"}{"entity_agent_addr_line3"} = 1;
$exclude{"prop"}{"entity_agent_city"} = 1;
$exclude{"prop"}{"entity_agent_state"} = 1;
$exclude{"prop"}{"entity_agent_country"} = 1;

$indices{"prop"} = "appr_addr_zip,assessed_val,appraised_val";

$mode = 0;

print "create database tcad;\n";
print "use tcad;\n\n";

while ($line = <>)
{
  chop $line;

  if ($mode == 0 && $line =~ /^Short file name \((.*)\)/)
  {
    $filename = $1;
    $filename =~ s/Arbitration/ARBITRATION/;
    $filename = "UDI.TXT" if $filename eq "UDI_7_8.TXT";
    $filename =~ /^(.*).TXT/;
    $table = $1;
    $table =~ tr/A-Z/a-z/;
    $mode = 1;
    print "create table $table (";
    next;
  }

  if ($mode == 1 && $line =~ /^Field Name,Datatype,/)
  {
    $mode = 2;
    $first = 1;
    $count = 0;
    next;
  }

  if ($mode == 2 && $line =~ /^,,/)
  {
    print "\n) row_format=dynamic engine=innodb;\n";
    $mode = 0;

    print "load data local infile '$filename' into table $table (\@line) set\n  ";
    for ($i = 0; $i < $count; $i++)
    {
      print ",\n  " if $i > 0;
      print "$name[$i] = SUBSTR(\@line, $start[$i], $len[$i])";
      # Need to cast to a number or mysql will complain on an empty string
      #print " + 0" if $types[$i] eq "float";
      print " + 0" if $types[$i] eq "float" || $types[i] =~ /int/;
    }
    print ";\n\n";

    @indices = split(/,/, $indices{$table});
    foreach $i (@indices)
    {
      #next if !$i;
      print "create index ".$i."_ind on $table ($i);\n";
    }

    next;
  }

  if ($mode == 2)
  {
    @parts = split(/,/, $line);
    # Weed out lines that are continuations of a prior definition
    next if @parts < 4 || $parts[2] + $parts[4] - 1 != $parts[3];

    $parts[0] =~ s/\/ //g;
    $parts[0] =~ s/(A-Z)/_$1/g;
    $parts[0] =~ s/^_//;
    $parts[0] =~ tr/A-Z/a-z/;
    $parts[0] =~ s/ /_/g;

    # The stupid layout document often has more than one entry called "filler"
    next if $parts[0] eq "filler";

    print ($first? "": ",");
    $first = 0;

    $parts[1] =~ /^(.*)\((.*)\)/;
    $len = $2;
    $parts[1] = "mediumtext" if $len >= 200;
    $parts[1] = "char($len)" if $parts[1] =~ /varchar/ && $len < 3;

    $parts[1] = "float" if $parts[1] =~ /numeric/;
    $parts[1] =~ s/char/varchar/;
    $parts[1] =~ s/varvarchar/varchar/;
    $parts[1] =~ s/`$//;
    $parts[1] =~ s/varcahr/varchar/;

    if ($exclude{$table}{$parts[0]})
    {
      print "\n# excluding: $parts[0]";
    }
    else
    {
      print "\n$parts[0] $parts[1]";
      $name[$count] = $parts[0];
      $start[$count] = $parts[2];
      $len[$count] = $parts[4];
      $types[$count] = $parts[1];
      $count++;
    }
  }
}
