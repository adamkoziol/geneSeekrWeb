=head1 NAME
   HTML - A module for data display (produce HTML)

=head1 SYNOPSIS
   use HTML
   #include sub name here

=head1 DESCRIPTION
   wgsHTML is responsible for producing the HTML from the data produced by DATA             

=head1 EXAMPLES

=head1 NOTES

=head1 AUTHOR
   Rene Warren April 2003
=cut


package HTML;

use lib ".";
use strict;
use DATA;
use LWP::UserAgent;


#----------------------------------
sub menuHome{

   my ($userinfo,$current,$menu,$compressed_userinfo,$keyword,$htdocs_path,$img,$datechoice,$currentdate,$yr)=@_;

   my $startdate = $keyword . "-01";
   my $endate = $keyword . "-31";

   if($keyword eq "YTD"){
      $startdate = $yr . "-01-01";
      $endate = $currentdate . "-31";
   }

   print "<tr><td>&nbsp;</td></tr>";
   print "<tr><td>&nbsp;</td></tr>";
   print "<tr><td align=center><b>STATS for </b>";
   print "<SELECT NAME='table' onChange='top.location.href=\"$current?menu=$menu&data=$compressed_userinfo&kw=\"+this.options[selectedIndex].value+\"\";' Size='1'>";
   HTML::arraySelectionBox($datechoice,$keyword);
   print "</SELECT>";

   print "</td></tr>";


   ###getData
   my $tbl_bill = "bills";
   my $tbl_pur  = "purchases";
   my $tbl_inc  = "income";
   my $tbl_cre  = "credit";

   my $field_name = "date";
   
   my ($list1,$query1) = DATA::getAllDate($userinfo,$tbl_bill,$field_name,$startdate,$endate);
   my ($list2,$query2) = DATA::getAllDate($userinfo,$tbl_pur,$field_name,$startdate,$endate);
   my ($list3,$query3) = DATA::getAllDate($userinfo,$tbl_inc,$field_name,$startdate,$endate);  
   my ($list4,$query4) = DATA::getAllDate($userinfo,$tbl_cre,$field_name,$startdate,$endate);

   my $credits=0;
   foreach my $line(@$list4){
      my $el=0;
      foreach my $value (@$line){
         $credits+=$value if($el==2);
         $el++;
      }
   }

   ###analyzeData
   my $bills=0;
   foreach my $line(@$list1){
      my $el=0;
      foreach my $value (@$line){
         $bills+=$value if($el==2);
         $el++;
      }
   }
   my $pur=0;
   foreach my $line(@$list2){
      my $el=0;
      foreach my $value (@$line){
         $pur+=$value if($el==2);
         $el++;
      }
   }
   my $inc=0;
   foreach my $line(@$list3){
      my $el=0;
      foreach my $value (@$line){
         $inc+=$value if($el==2);
         $el++;
      }
   }

   my $balance = $inc - ($bills + $credits);
   my $left = $inc - ($bills + $pur);
   my $fontcol="000000";
   my $message="";
   my $fontcolc="000000";
   my $messagec="";


   if($left < 0){
      $fontcol  = "FF0000";
      $message = "OWING";
   }else{
      $fontcol = "228b22";
      $message = "LEFT";
   }

   if($balance < 0){
      $fontcolc  = "FF0000";
      $messagec = "OWING";
   }else{
      $fontcolc = "228b22";
      $messagec = "LEFT";
   }


   ###presentData

   print "<tr><td>&nbsp;</td></tr>";
   printf "<tr><td align=center><font color =228b22 >Income = \$ %.2f</font></td></tr>", $inc;
   printf "<tr><td align=center><font color = FF0000>Bills = \$ %.2f</font></td></tr>", $bills;

   print "<tr><td align=center><table valign=center halign=center width=400 border=2>";
   print "<tr><td><table width=200 border=0>";
   print "<tr><td align=center><b>BUDGET</b></td></tr>";
   print "<tr><td>&nbsp;</td></tr>";
   printf "<tr><td align=center><font color = FF0000>Purchases = \$ %.2f</font></td></tr>", $pur;
   print "<tr><td align=center>===============</td></tr>";
   printf "<tr><td align=center><font color=$fontcol>\$ %.2f $message</font</td></tr>", $left;
   print "</table></td>";

   print "<td><table width=200 border=0>";
   print "<tr><td align=center><b>\$PENT</b></td></tr>";
   print "<tr><td>&nbsp;</td></tr>";
   printf "<tr><td align=center><font color = FF0000>Credits = \$ %.2f</font></td></tr>", $credits;
   print "<tr><td align=center>===============</td></tr>";
   printf "<tr><td align=center><font color=$fontcol>\$ %.2f $message</font</td></tr>", $balance;
   print "</table></td>";

   print "</tr></table></td></tr>";
}

#----------------------------------
sub menuSearchRecord{

   my ($verdict,$userinfo,$current,$menu,$compressed_userinfo,$newtable,$table,$htdocs_path,$field_name,$search,$keyword)=@_;

   my $tableList = DATA::getAllTableNames($userinfo);
   my $fieldList = DATA::getFields($userinfo,$table);

   my (@tableArray,@fieldArray);   

   foreach my $tl(@$tableList){
      my @record=@$tl;
      push @tableArray,$record[0];
   }

   foreach my $fl(@$fieldList){
      my @record=@$fl;
      push @fieldArray,$record[0];
   }

   print "<FORM ACTION=\"$current\" METHOD='POST'>";
   print "<tr><td>&nbsp;</td></tr>";
   print "<tr><td align=center><i>$verdict</i></td></tr>";
   print "<tr><td>&nbsp;</td></tr>";
   print "<tr><td align=center>Search table ";

   print "<SELECT NAME='table' onChange='top.location.href=\"$current?menu=$menu&data=$compressed_userinfo&table=\"+this.options[selectedIndex].value+\"\";' Size='1'>";
   HTML::arraySelectionBox(\@tableArray,$table);
   print "</SELECT>";

   print "&nbsp;where ";

   print "<SELECT NAME='field_name' Size='1'>";
   HTML::arraySelectionBox(\@fieldArray,$field_name);
   print "</SELECT>";

   print "&nbsp;has keyword ";

   print "<input type=text name=keyword value=$keyword>";
   print "<input type=submit value=\"Go\">";
   print "</td></tr>";

   print "<INPUT TYPE='hidden' NAME='menu' VALUE=$menu>";
   print "<INPUT TYPE='hidden' NAME='table' VALUE=$table>";
   print "<INPUT TYPE='hidden' NAME='data' VALUE=$compressed_userinfo>";
   print "<INPUT TYPE='hidden' NAME='search' VALUE=1>";
   print "</FORM>";

   if($search){
      my ($list,$query) = DATA::getAll($userinfo,$table,$field_name,$keyword);
      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center>$query</td></tr>";
      print "<tr><td align=center><table border=1 cellspacing=1 cellpadding=1>";
      print "<tr>";
      foreach my $head(@fieldArray){
         print "<th>$head</th>";
      }
      print "</tr>";

      my $sum=0;
      foreach my $line(@$list){
         print "<tr>";
         my $el=0;
         foreach my $value (@$line){
            $sum+=$value if($el==2);
            print "<td>$value</td>";
            $el++;
         }
         print "</tr>";
      }
      print "<tr><td colspan=2 align=right>total:</td><td colspan=3>\$ $sum</td></tr>";
      print "</table>";
   }

}

#----------------------------------
sub menuEditRecord{

      my ($verdict,$userinfo,$current,$menu,$compressed_userinfo,$newtable,$table,$htdocs_path,$record_id)=@_;

      my $field = DATA::getIdName($userinfo,$table);
      my $selection;

      foreach my $rec (@$field){
         my @record = @$rec;
         my $concat = $record[1] . "_" . $record[2];
         $selection->{$record[0]} = $concat;
      }

      print "<FORM ACTION=\"$current\" METHOD='POST'>";
      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center><i>$verdict</i></td></tr>";
      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center>Edit record ";
      print "<SELECT NAME='record_id' Size='1'>";
      HTML::simpleSelectionBox($selection,$record_id);
      print "</SELECT>";
      print "&nbsp;in ";
      print "<SELECT NAME='table' onChange='top.location.href=\"$current?menu=$menu&data=$compressed_userinfo&table=\"+this.options[selectedIndex].value+\"\";' Size='1'>";
      HTML::arraySelectionBox($newtable,$table);
      print "</SELECT>";

      print "&nbsp;table&nbsp;";
      print "<input type=submit value=\"Go\">";
      print "</td></tr>";

      print "<INPUT TYPE='hidden' NAME='menu' VALUE=$menu>";
      print "<INPUT TYPE='hidden' NAME='table' VALUE=$table>";
      print "<INPUT TYPE='hidden' NAME='data' VALUE=$compressed_userinfo>";
      print "</FORM>";

      #### if retrieve <----
      if($record_id){
         my $record_info = DATA::getSingleRecord($userinfo,$table,$record_id);
         my $field = DATA::getFields($userinfo,$table);

         print "<tr><td>";
         HTML::editRecord($current,$menu,$userinfo,$compressed_userinfo,$field,$table,$htdocs_path,$record_info,$record_id);
         print "</td></tr>";
      } 
}

#----------------------------------
sub menuAddRecord{

      my ($verdict,$userinfo,$current,$menu,$compressed_userinfo,$newtable,$table,$htdocs_path,$username)=@_;

      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center><i>$verdict</i></td></tr>";
      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center>Add a new record in ";
      print "<SELECT NAME='table' onChange='top.location.href=\"$current?menu=$menu&data=$compressed_userinfo&table=\"+this.options[selectedIndex].value+\"\";' Size='1'>";
      HTML::arraySelectionBox($newtable,$table);
      print "</SELECT>";
      print "&nbsp;</td></tr>";
    

      my $field = DATA::getFields($userinfo,$table);

      print "<tr><td>";
      HTML::addRecord($current,$menu,$userinfo,$compressed_userinfo,$field,$table,$htdocs_path,$username);
      print "</td></tr>";
 
}

#----------------------------------
sub menuAddRecords{

      my ($verdict,$userinfo,$current,$menu,$compressed_userinfo,$newtable,$table,$htdocs_path,$fields,$values,$platesize,$rim)=@_;

      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center><i>$verdict</i></td></tr>";
      print "<tr><td>&nbsp;</td></tr>";
      print "<tr><td align=center>Add a new record in ";
      print "<SELECT NAME='table' onChange='top.location.href=\"$current?menu=$menu&data=$compressed_userinfo&table=\"+this.options[selectedIndex].value+\"\";' Size='1'>";
      HTML::arraySelectionBox($newtable,$table);
      print "</SELECT>";
      print "&nbsp;</td></tr>";
   

      my $field = DATA::getFields($userinfo,$table);

      print "<tr><td>";
      HTML::addBulk($current,$menu,$userinfo,$compressed_userinfo,$field,$table,$htdocs_path,$fields,$values,$platesize,$rim);
      print "</td></tr>";

}

#----------------------------------
sub printMenuLinks{

   my ($current,$menu,$compressed_userinfo) = @_;

   my $lc = "7f7f7f";
   my ($m1,$m2,$m3,$m4)=($lc,$lc,$lc,$lc);
   if($menu==1){  $m1="000000";  }elsif($menu == 2){ $m2 = "000000"; }elsif($menu == 3){  $m3 = "000000";  }elsif($menu == 4){  $m4 = "000000";}

   print "<table width=680 >";
   print "<tr>";
   print "<th><a style=\"text-decoration:none\" href=\"$current?menu=1&data=$compressed_userinfo\" alt=\"Go to main menu\" title=\"Go to main menu\"><font color=\"$m1\"><i>home</i></font></a></th>";
   print "<th><a style=\"text-decoration:none\" href=\"$current?menu=2&data=$compressed_userinfo\" alt=\"Add a new record\" title=\"Add a new record\"><font color=\"$m2\"><i>new</i></font></a></th>";
   print "<th><a style=\"text-decoration:none\" href=\"$current?menu=3&data=$compressed_userinfo\" alt=\"Edit an existing record\" title=\"Edit an existing record\"><font color=\"$m3\"><i>edit</i></font></a></th>";
   print "<th><a style=\"text-decoration:none\" href=\"$current?menu=4&data=$compressed_userinfo\" alt=\"Search records\" title=\"Search records\"><font color=\"$m4\"><i>search</i></font></a></th>";
   print "</tr>";
   print "</td></tr></table>";
}

#----------------------------------
sub logMeIn{

   my ($scriptname,$menu,$userinfo) = @_;

   my ($comment, $color);

   if ($userinfo->{'pass'}==-1){
      $comment="*user not logged in";
      $color="d2691e";
   }elsif(! $userinfo->{'pass'}){
      $comment="*login failed";
      $color="FF0000";
   }elsif($userinfo->{'pass'}){
      $comment="*logged in";
      $color="228b22";
   }

   print "<table border=1 align=center cellpadding=0 cellspacing=0>";
   print "<tr><td><table>";
   print "<FORM ACTION=\"$scriptname\" METHOD=\"POST\" ENCTYPE=\"multipart/form-data\">";
   print "<tr><td align=right>username&nbsp;</td><td align=center><INPUT TYPE=\"text\" NAME=\"username\" VALUE=\"\" SIZE=\"10\" MAXLENGTH=\"10\"></td>";
   print "<td align=right>&nbsp;password&nbsp;</td><td align=center><INPUT TYPE=\"password\" NAME=\"access\" VALUE=\"\" SIZE=\"10\" MAXLENGTH=\"10\"></td>";
   print "<INPUT TYPE=\"hidden\" NAME=\"menu\" VALUE=\"$menu\">";
   print "<td align=left><INPUT TYPE=\"SUBMIT\" VALUE=\"Log In\"></td>";
   print "</FORM>";

   print "<FORM ACTION=\"$scriptname\" METHOD='POST'>";
   print "<td align=left><INPUT TYPE=\"SUBMIT\" VALUE=\"Log Out\"></td>";
   print "</FORM>";
   print "</tr>";
   print "<tr><td colspan=6 align=center><font color=$color>$comment</font></td></tr>";
   print "</table></td></tr>";
   print "</table>";

}

#----------------------------------
sub login{

   my ($scriptname,$menu,$userinfo) = @_;

   print "<table border=1 bordercolor='D3D3D3' width=430 align=center>";
   print "<tr><td>";
   print "<table border=0 width=430 align=center>";
   &showLoginTable($scriptname,$menu,$userinfo);
   print "</table>";
   print "</td></tr>";
   print "</table>";

}

#----------------------------------
sub addBulk{

   my ($scriptname,$menu,$userinfo,$compressed_userinfo,$field,$table,$htdocs_path,$fields,$values,$platesize,$rim) = @_;
   my @values=@$values;
   my @fields=@$fields;
   my $totfields = $#fields + 2;

   my ($cantProceed,$noRecordFlag) = (0,0);

   #print "<FORM ACTION=\"$scriptname\" METHOD=\"POST\" ENCTYPE=\"multipart/form-data\" >";

   print "<table border=1 cellpadding=0 cellspacing=0 align=center>";
   print "<tr><td><table border=1>";
   print "<tr>";
   ###HEADER:

   my @wellselect=();
   foreach my $rec (@$field){
      my @record=@$rec;
      print "<th>#</th>" if($record[0] eq 'id');
      print "<th>$record[0]</th>" if($record[0] ne 'id');
      if($record[0] =~/well/ && $record[1]=~/enum\((.*)\)/){
         my $string =$1; 
         $string=~s/\'//g;
         @wellselect=split(",",$string);
      }
   }
   print "</tr>";

   my @norimarray=(14,15,16,17,18,19,20,21,22,23,26,27,28,29,30,31,32,33,34,35,38,39,40,41,42,43,44,45,46,47,50,51,52,53,54,55,56,57,58,59,62,63,64,65,66,67,68,69,70,71,74,75,76,77,78,79,80,81,82,83,86,87,88,89,90,91,92,93,94,95,98,99,100,101,102,103,104,105,106,107);

   if((! $rim && $platesize > ($#norimarray+1)) || ($rim && $platesize > ($#wellselect+1) ) ){

      print "<tr><td align=center colspan=$totfields bgcolor=FF0000>ERROR: YOU WANT TO ADD MORE RECORDS THAN THE TOTAL NUMBER OF AVAILABLE WELLS, GO BACK AND RETRY WITH LESS RECORDS.</td></tr>";
      print "</table></td></tr>";
      print "</table>";

   }else{

   print "<FORM ACTION=\"$scriptname\" METHOD=\"POST\" ENCTYPE=\"multipart/form-data\" >";
   #---
   my $buffer = 0;
   if($table eq 'elispot'){
      if($platesize > 8){
         $buffer = 7;
      }else{
         $rim = 1;          ### force the inclusion of rim wells since otherwise that wouldn' make much sense
         $buffer = -1;
      }
   }
   #---
 
   foreach (my $line=1;$line<=$platesize;$line++){
      print "<tr>";

      my $wellelement = $buffer + $line;
      $wellelement = $norimarray[$line-1]+$buffer if(! $rim);

      foreach my $rec (@$field){
         my @record = @$rec;
         my $nameconcat = $record[0] . $line; 
         my $ctorder=0;
         CYCLE:
         foreach my $att(@fields){
            if($att eq $record[0]){last CYCLE;}
            $ctorder++;
         }

         if($record[0] eq 'id'){
            print "<td>$line</td>"; 
         }elsif($record[0]=~/[FP]K\_(\S+)\_{2}/){
            my $tbl = $1;
            my $field2 = DATA::getIdName($userinfo,$tbl);
            my $selection;
            my $existRecordFlag=0;
            my $message="";

            foreach my $rec2 (@$field2){
               my @record2 = @$rec2;
               my $concat = $record2[1];
               $selection->{$record2[0]} = $concat;
               $existRecordFlag++;
            }
            if(! $existRecordFlag && $record[0]=~/^FK\_/){$cantProceed++;$message = "Create first!";}

            if($tbl eq "pool" || $record[0] =~ /FK_internalSample/){
               print "<td align=center valign=center bgcolor=FFFF99>";
               print "<select NAME=$nameconcat>";
               my $passid = $values[$ctorder] + ($line-1);
               HTML::simpleSelectionBox($selection,$passid);
               print "</select>";
               print "<font color=FF0000>&nbsp;$message</font></td>";
            }else{
               print "<td>$selection->{$values[$ctorder]}</td>";
               print "<INPUT TYPE='hidden' NAME=$nameconcat VALUE=$values[$ctorder]>";
            }
 
         }elsif($record[0] =~/well/){
            #print "<td>$wellselect[$wellelement]";
            print "<td bgcolor=FFFF99><select NAME=$nameconcat>";
            arraySelectionBox2(\@wellselect,$wellelement);
            print "</select>";
            print "</td>";
            #print "<INPUT TYPE='hidden' NAME=$nameconcat VALUE=$wellselect[$wellelement]>";

          }elsif($record[0] =~/type/ && $record[1]=~/enum\((.*)\)/){
            my $string =$1;
            $string=~s/\'//g;
            my @choice=split(",",$string);
            print "<td bgcolor=FFFF99>";
            print "<select NAME=$nameconcat>";
            arraySelectionBox(\@choice,$values[$ctorder]);
            print "</select>";
            print "</td>";

         }elsif($record[0]=~/notes/){
            print "<td bgcolor=FFFF99><textarea name=$nameconcat rows=5 cols=25>";
            print "$values[$ctorder]";
            print "</textarea></td>";

         }elsif($record[0]=~/PBMC/ || $record[0]=~/viability/ || $record[0]=~/spots/ || $record[0]=~/image/ || $record[0]=~/Cells/){
            print "<td bgcolor=FFFF99><INPUT TYPE=TEXT NAME=$nameconcat size=25 value=\"$values[$ctorder]\" ></td>";
         }elsif($record[0]=~/name/){
            print "<td bgcolor=FFFF99><INPUT TYPE=TEXT NAME=$nameconcat size=25 value=\"$values[$ctorder]-$wellselect[$wellelement]\" ></td>";
         }else{
            print "<td>$values[$ctorder]</td>";
            print "<INPUT TYPE='hidden' NAME=$nameconcat VALUE=$values[$ctorder]>";
         }
      }
      print "</tr>";
   }

   print "<tr><td align=center colspan=$totfields bgcolor=FF0000><INPUT TYPE='submit' value=\"Add\" onClick=\"return confirm('Insert $platesize records into table $table ?')\"></td></tr>" if(! $cantProceed);
   print "<INPUT TYPE='hidden' NAME='table' VALUE=$table>";
   print "<INPUT TYPE='hidden' NAME='menu' VALUE=$menu>";
   print "<INPUT TYPE='hidden' NAME='data' VALUE=$compressed_userinfo>";
   print "<INPUT TYPE='hidden' NAME='platesize' VALUE=$platesize>";
   print "<INPUT TYPE='hidden' NAME='addmany' VALUE=1>";
   print "</FORM>";
   print "</table></td></tr>";
   print "</table>";

   }
}


#----------------------------------
sub addRecord{
   
   my ($scriptname,$menu,$userinfo,$compressed_userinfo,$field,$table,$htdocs_path,$username) = @_;

   my ($cantProceed,$noRecordFlag) = (0,0);

   print "<FORM ACTION=\"$scriptname\" METHOD=\"POST\" ENCTYPE=\"multipart/form-data\" >";

   print "<table border=1 cellpadding=0 cellspacing=0 align=center>";
   print "<tr><td><table>";

   foreach my $rec (@$field){
      my @record = @$rec;
      print "<tr>";
      if($record[0] ne "id"){
         print "<td align=right>$record[0]</td>";
         if($record[0]=~/[FP]K\_(\S+)\_{2}/){
            my $field2 = DATA::getIdName($userinfo,$1);
            my $selection;
            my $existRecordFlag=0;
            my $message="";
            foreach my $rec2 (@$field2){
               my @record2 = @$rec2;
               #my $concat = $record2[0] . " - " . $record2[1];            
               my $concat = $record2[1];
               $selection->{$record2[0]} = $concat;
               $existRecordFlag++;
            }
            if(! $existRecordFlag && $record[0]=~/^FK\_/){$cantProceed++;$message = "Create first!";}
            print "<td>";
            print "<select NAME=$record[0]>";
            HTML::simpleSelectionBox($selection,"");
            print "</select>";
            print "<font color=FF0000>&nbsp;$message</font></td>";
           
         }elsif($record[1]=~/enum\((.*)\)/){
            my @choice=split(",",$1);
            print "<td>";
            print "<select NAME=$record[0]>";
            HTML::arraySelectionBox(\@choice,"");
            print "</select>";
            print "</td>";            
         }elsif($record[1]=~/date/){

            ### defaults the date
            my $currentDate = `date "+%Y-%m-%d %H:%M:%S"`;
            chomp($currentDate);

            print "<td>";
            print "<input id='$record[0]' NAME=$record[0] VALUE=$currentDate TYPE=text size=25>";
            print "<a href=\"javascript:NewCssCal('$record[0]','yyyymmdd','dropdown',true)\">";
            print "<img src=\"/images/cal.gif\" width=16 height=16 border=0 alt=\"Pick a date\">";
            print "</a>";
            print "</td>";
         }elsif($record[0]=~/user/){ 
            print "<td><INPUT TYPE=TEXT NAME=$record[0] size=25 value=\"$username\" ></td>";
         }elsif($record[0]=~/notes/){
            print "<td><textarea name=$record[0] rows=5 cols=25>";
            print "</textarea></td>"; 
         }elsif($record[0]=~/name/){  ### i guess name is a reserved word
            print "<td><INPUT TYPE=TEXT NAME='namer' size=25 value=\"\" ></td>";
         }else{
            print "<td><INPUT TYPE=TEXT NAME='$record[0]' size=25 value=\"\" ></td>"; 
         }
      }      

      print "</tr>";
   }
   
   print "<tr><td>&nbsp;</td></tr>";
   print "<tr><td>&nbsp;</td><td align=left><INPUT TYPE='submit' value=\"Add\" onClick=\"return confirm('Insert record *' + namer.value + '* into table $table ?')\"></td></tr>" if(! $cantProceed);
   print "<tr><td>&nbsp;</td><td align=left><INPUT TYPE='reset'></td></tr>";
   print "<tr><td align=right bgcolor=FFFF99>#records&nbsp;<INPUT TYPE=TEXT NAME=platesize size=3 value=\"\">&nbsp;RimWells?&nbsp;<input type='checkbox' name='rim' value=1></td><td align=left bgcolor=FFFF99><INPUT TYPE='submit' value=\"Bulk Entry\" name='bulk' onClick=\" return confirm('MAKE SURE ALL FIELDS OF THIS FORM ARE FILLED !')\"></td></tr>" if($table eq 'internalSample' || $table eq 'elispot');
   print "<INPUT TYPE='hidden' NAME='table' VALUE=$table>";
   print "<INPUT TYPE='hidden' NAME='menu' VALUE=$menu>";
   print "<INPUT TYPE='hidden' NAME='data' VALUE=$compressed_userinfo>";
   print "<INPUT TYPE='hidden' NAME='insert' VALUE=1>";
   print "</FORM>";
   print "</table></td></tr>";
   print "</table>";

}

#----------------------------------
sub editRecord{

   my ($scriptname,$menu,$userinfo,$compressed_userinfo,$field,$table,$htdocs_path,$record_info,$record_id) = @_;
   my @record_info = @$record_info;
  
   my ($cantProceed,$noRecordFlag) = (0,0);

   print "<FORM ACTION=\"$scriptname\" METHOD=\"POST\" ENCTYPE=\"multipart/form-data\" >";

   print "<table border=1 cellpadding=0 cellspacing=0 align=center>";
   print "<tr><td><table>";

   my $order=0;
   foreach my $rec (@$field){
      my @record = @$rec;
      print "<tr>";
      if($record[0] ne "id"){
         print "<td align=right>$record[0]</td>";
         if($record[0]=~/[FP]K\_(\S+)\_{2}/){

            my $field2 = DATA::getIdName($userinfo,$1);
            my $selection;
            my $existRecordFlag=0;
            my $message="";
            foreach my $rec2 (@$field2){
               my @record2 = @$rec2;
               #my $concat = $record2[0] . " - " . $record2[1];
               my $concat = $record2[1];
               $selection->{$record2[0]} = $concat;
               $existRecordFlag++;
            }
            if(! $existRecordFlag){$cantProceed++;$message = "Create first!";}
            print "<td>";
            print "<select NAME=$record[0]>";
            HTML::simpleSelectionBox($selection,$record_info[$order]);
            print "</select>";
            print "<font color=FF0000>&nbsp;$message</font></td>";

        }elsif($record[1]=~/enum\((.*)\)/){

            my @choice=split(",",$1);
            print "<td>";
            print "<select NAME=$record[0]>";
            HTML::arraySelectionBox(\@choice,$record_info[$order]);
            print "</select>";
            print "</td>";

         }elsif($record[1]=~/date/){

            print "<td>";
            print "<input id='$record[0]' NAME=$record[0] TYPE=text size=25 value=\"$record_info[$order]\">";
            print "<a href=\"javascript:NewCssCal('$record[0]','yyyymmdd','dropdown',true)\">";
            print "<img src=\"/images/cal.gif\" width=16 height=16 border=0 alt=\"Pick a date\">";
            print "</a>";
            print "</td>";

         }elsif($record[0]=~/notes/){

            print "<td><textarea name=$record[0] rows=5 cols=25>";
            print "$record_info[$order]";
            print "</textarea></td>";

         }elsif($record[0]=~/name/){  ### i guess name is a reserved word
            print "<td><INPUT TYPE=TEXT NAME='namer' size=25 value=\"$record_info[$order]\"></td>";
         }else{
            print "<td><INPUT TYPE=TEXT NAME='$record[0]' size=25 value=\"$record_info[$order]\"></td>";
         }
      }

      print "</tr>";
      $order++;
   }

   print "<tr><td>&nbsp;</td></tr>";
   print "<tr><td>&nbsp;</td><td align=left><INPUT TYPE='submit' value=\"Edit\" onClick=\"return confirm('Edit record *' + namer.value + '* from table $table ?')\"></td></tr>" if(! $cantProceed);
   print "<INPUT TYPE='hidden' NAME='table' VALUE=$table>";
   print "<INPUT TYPE='hidden' NAME='menu' VALUE=$menu>";
   print "<INPUT TYPE='hidden' NAME='data' VALUE=$compressed_userinfo>";
   print "<INPUT TYPE='hidden' NAME='record_id' VALUE=$record_id>";
   print "<INPUT TYPE='hidden' NAME='update' VALUE=1>";

   print "</FORM>";

   print "</table></td></tr>";
   print "</table>";
}




#----------------------------------
sub showLoginTable{

   
   my ($scriptname,$menu,$userinfo) = @_;

   my ($comment, $color);

   if ($userinfo->{'pass'}==-1){
      $comment="*User not logged in";
      $color="d2691e";
   }elsif(! $userinfo->{'pass'}){
      $comment="*Login failed";
      $color="FF0000";
   }elsif($userinfo->{'pass'}){
      $comment="*Logged in";
      $color="228b22";
   }

   print "<tr><td colspan=3 align=center>&nbsp;</td></tr>";
   print "<FORM ACTION=\"$scriptname\" METHOD='POST'>";
   print "<tr><td align=right><span class=small><b>Username&nbsp;</b></span></td><td align=center><INPUT TYPE=\"text\" NAME=\"username\" VALUE=\"\" SIZE=\"16\" MAXLENGTH=\"20\"></td><td>&nbsp;</td></tr>";
   print "<tr><td align=right><span class=small><b>Password&nbsp;</b></span></td><td align=center><INPUT TYPE=\"password\" NAME=\"access\" VALUE=\"\" SIZE=\"16\" MAXLENGTH=\"20\"></td><td>&nbsp;</td></tr>";
   print "<INPUT TYPE=\"hidden\" NAME=\"menu\" VALUE=\"$menu\">";

   print "<tr><td>&nbsp;</td><td align=center><font color=$color><span class=small><b>$comment</b></span></font></td><td align=right><INPUT TYPE=\"SUBMIT\" VALUE=\"Log In\"></td></tr>";
   print "</FORM>";


}


######################## Common Code #####################
#------------------------------------------
sub setHTML{
    # print HTML from CGI script

    my $page=shift;
    my $htdocpath=shift;

    $page->AddJavaScript("$htdocpath/integrityCheck.js");
    $page->AddJavaScript("$htdocpath/winpopup.js");
    $page->SetEmail("warrenlr\@gmail.com");
    $page->SetContactEmail("rwarren\@bcgsc.bc.ca");
    $page->SetContactName("Rene Warren");
    $page->SetDebugFlag(0);
    $page->TopBar();

    print "<link rel=\"stylesheet\" type=\"text/css\" media=\"screen\" href=\"/site-style/common.css\">";

    return $page;
}

#------------------------------------------
sub printTitle{

    my $htdocpath=shift;
    my $project=shift;
    my @project=@$project;
    my $pass=shift;
    my $fuzzykey=shift;
    my $scriptname=shift;

    my $project_image_url="$htdocpath/$project[3]";
    my $ua = new LWP::UserAgent;
    my $request = new HTTP::Request('GET',$project_image_url);
    $ua->protocols_allowed( [ 'http', 'https'] );
    my $response = $ua->request($request);

    my $code=$response->code;
    print "<table width=680 border=0>";
    print "<tr>";
    print "<td valign=top><table border=0 cellspacing=0 cellpadding=0>";

    print "<tr><td valign=top><table border=0>";
    print "<tr><td><A HREF=\"$scriptname\"><IMG SRC=$project_image_url BORDER=0 ALT=\"$project[0] WGS home page\" TITLE=\"$project[0] WGS home page\"></A></td></tr>"; #if ($code);
    print "</table></td><td valign=top><table border=0>";
    print "<tr><td><span class=vlarge><font color='FF6666'><b>$project[0]</b></FONT></span></td></tr>";
    print "<tr><td><b><i>&nbsp;&nbsp;&nbsp;&nbsp;$project[1]</i></b><td></tr>";
    print "</table></td></tr>";

    print "</table></td>";
    print "<td valign=top align=right><table border=0>";
    if ($pass==1){
        print "<FORM ACTION=\"$scriptname\" METHOD='POST'>";
        print "<tr><td align=right><INPUT TYPE=\"image\" SRC=\"$htdocpath/samlogout.gif\" ALT=\"Logout from SAM\" TITLE=\"Logout from SAM\" NAME=\"\" VALUE=\"Log Out\"></td></tr>";
        print "<INPUT TYPE=\"hidden\" NAME=\"fuzzykey\" VALUE=\"$fuzzykey\">";
        print "</FORM>";
    }else{
        print "<tr><td>&nbsp;</td></tr>";
    }
 
    print "</table></td></tr>";
    print "<tr><td>&nbsp;</td></tr>" if ($pass !=1);
    print "</table>";

}

#------------------------------------------
sub printLink{

   my $scriptname=shift;
   my $assembly_id=shift; 
   my $gene_finder_id=shift;
   my $htdocpath=shift;
   my $fuzzykey=shift;
   my $compressed_userinfo=shift;
   my $menu=shift;

   my ($link0,$link1,$link2,$link3,$link4,$link5,$link6,$link7, $link8, $link9); 
   $link0=$link1=$link2=$link3=$link4=$link5=$link6=$link7=$link8=$link9='0000FF';

   if($menu==0 || $menu==99){
      $link0='000000';
   }elsif($menu==1){
      $link1='000000';
   }elsif($menu==2){
      $link2='000000';
   }elsif($menu==3){
      $link3='000000';
   }elsif($menu==4){
      $link4='000000';
   }elsif($menu==5){
      $link5='000000';
   }elsif($menu==6){
      $link6='000000';
   }elsif($menu==7){
      $link7='000000';
   }elsif($menu==8){
      $link8='000000';
   }elsif($menu==9){
      $link9='000000';
   }

   print "<table width=680 border=0>";
   print "<tr>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link0>Home</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=1&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link1>Assembly Details</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=2&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link2>Compare</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=3&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link3>Contig View</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=4&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link4>Map View</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=5&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link5>ORFs</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=6&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link6>Blast</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=7&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link7>Order</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$htdocpath/report/\"><font color=$link8>Reports</font></A></span></td>";
   print "<td width=112 align=center><span class=small><A HREF=\"$scriptname?menu=9&assembly_id=$assembly_id&gene_finder_id=$gene_finder_id&fuzzykey=$fuzzykey&data=$compressed_userinfo\"><font color=$link9>SAM</A></font></span></td>";
   print "</tr>";
   print "<tr><td colspan=10><HR noshade=1></td></tr>";
   print "</table>";

}

#------------------------------------------
sub assemblerBox{

   my $tmp_build=shift;
   my $assembly_id=shift;
   
   my @build_ref=@$tmp_build;

   foreach my $reference(@build_ref){
      my @assembler_arr=@$reference;

      if ($assembly_id==$assembler_arr[2]){
         print "<OPTION VALUE=$assembler_arr[2] SELECTED>$assembler_arr[0] Build $assembler_arr[1]  $assembler_arr[3]</OPTION>";
      }else{
         print "<OPTION VALUE=$assembler_arr[2]>$assembler_arr[0] Build $assembler_arr[1]  $assembler_arr[3]</OPTION>";
      }
   }
}

#------------------------------------------
sub simpleSelectionBox{

   my ($selection,$current_id) = @_;
  
   foreach my $any_id (sort {$b<=>$a} keys %$selection){

      if ($current_id==$any_id){
         print "<OPTION VALUE=$any_id SELECTED>$selection->{$any_id}</OPTION>";
      }else{
         print "<OPTION VALUE=$any_id>$selection->{$any_id}</OPTION>";
      }
   }
}

#------------------------------------------
sub arraySelectionBox{

   my ($selection,$current_id) = @_;
 
   foreach my $element (@$selection){
      #$element = $1 if($element=~/(\w+\-?(\w+)?)/);

      if ($current_id eq $element){
         print "<OPTION VALUE=$element SELECTED>$element</OPTION>";
      }else{
         print "<OPTION VALUE=$element>$element</OPTION>";
      }
   }
}


#------------------------------------------
sub arraySelectionBox2{

   my ($selection,$current_id) = @_;

   my $el=0;
   foreach my $element (@$selection){

      if ($current_id == $el){
         print "<OPTION VALUE=$element SELECTED>$element</OPTION>";
      }else{
         print "<OPTION VALUE=$element>$element</OPTION>";
      }
      $el++;
   }
}


1;
