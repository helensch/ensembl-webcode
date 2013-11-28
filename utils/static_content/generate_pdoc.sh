#!/bin/sh

# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# This script generates a shell script and linking config files which are used
# to generate the 'pdoc' perl documentation.
#
# These scripts are generated in the P2WDOC_LOC directory defined below.
#
# The actual Pdoc software can be obtained from: 
# 	http://sourceforge.net/projects/pdoc
# or by:
#	cvs -d:pserver:anonymous@cvs.pdoc.sourceforge.net:/cvsroot/pdoc login
#
#	When prompted for the password, press 'Enter' key, then type:
#
#	cvs -z3 -d:pserver:anonymous@cvs.pdoc.sourceforge.net:/cvsroot/pdoc
#		co pdoc-live
#
# or contact Raphael Leplae (used to work at Sanger): lp1@sanger.ac.uk
#
#
# To generate the Pdocs, edit the variables below, and then run this script.  
# It will generate a script called make_html_docs.sh and a number of files (one
# for each Fnumber set of perl modules) which contain cross-linking information.#
# This script will change to P2QDOC_LOC and run the make_html_docs.sh script
# The Pdocs will be generated in the PDOC_LOC directory.  
# This script will mkdir each of the Fnumber directories in the PDOC_LOC 
# directory first: e.g. mkdir PDOC_LOC/bioperl-live, etc.
#
# jws 2002-01-08
#
# fc1 2005-10-21 edits
#
# dr2 2009-5-26 added -skip option in core documentation
#
# ap5 2010-12-09 added helper script for more comprehensive HTML munging 

#. /etc/profile

PERLMOD_LOC="/ensemblweb/www/www_61"   # current server root
#PERLMOD_LOC="/ensemblweb/www/server"   # current server root

PDOC_LOC="$PERLMOD_LOC/htdocs/info/docs/Pdoc"    # where you want Pdocs created
HTTP="/info/docs/Pdoc"
P2WDOC_LOC="/localsw/ensembl_web/pdoc-live"  # Pdoc code location
P2WDOCER="/localsw/ensembl_web/pdoc-live/scripts/perlmod2www.pl"
BIOPERL="/localsw/ensembl_web"
CSS_URL="/pdoc.css"

#F1=bioperl-live
F2=ensembl
F3=ensembl-analysis
F4=ensembl-compara
F5=ensembl-external
F6=ensembl-pipeline
F7=perl
F8=ensembl-variation
F9=ensembl-hive
F10=biomart-perl
F11=public-plugins
F12=ensembl-functgenomics

rm -f $P2WDOC_LOC/make_html_docs.*

cd $PERLMOD_LOC
(
  echo "#!/bin/sh"
  echo "# Script to generate HTML version of PERL docs using perlmod2www.pl"
  echo "# This script has been automatically generated by generate_pdoc.sh"
) > $P2WDOC_LOC/make_html_docs.sh

echo "Check out ensembl-pipeline, ensembl-analysis ensembl-hive"
cvs co ensembl-pipeline ensembl-analysis ensembl-hive

#for i in bioperl-live ensembl ensembl-analysis ensembl-compara ensembl-functgenomics ensembl-external ensembl-variation ensembl-hive perl biomart-perl public-plugins ensembl-pipeline
for i in ensembl ensembl-analysis ensembl-compara ensembl-functgenomics ensembl-external ensembl-variation ensembl-hive perl biomart-perl public-plugins ensembl-pipeline
do
  mkdir $PDOC_LOC/$i
  echo "CURRENT MODULE: $i"
  #cp $P2WDOC_LOC/Pdoc/Html/Data/perl.css $PDOC_LOC/$i 
 	echo "#CURRENT MODULE: $i" >> $P2WDOC_LOC/make_html_docs.sh 
  if test $i = "bioperl-live"
   then SOURCE="$BIOPERL/$i"
  else
    SOURCE="$PERLMOD_LOC/$i"
  fi
  if test $i = "ensembl"
   then	echo "$P2WDOCER -skip Collection,chimp,Lite,misc-scripts,docs,t -source $SOURCE -target $PDOC_LOC/$i -raw -webcvs http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/$i/?root=ensembl -css_url $CSS_URL -xltable $P2WDOC_LOC/$i.xlinks " >> $P2WDOC_LOC/make_html_docs.sh
 elif test $i = "ensembl-variation"
   then	echo "$P2WDOCER -skip scripts -source $SOURCE -target $PDOC_LOC/$i -raw -webcvs http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/$i/?root=ensembl -xltable $P2WDOC_LOC/$i.xlinks -css_url $CSS_URL" >> $P2WDOC_LOC/make_html_docs.sh
 else
 	echo "$P2WDOCER -source $SOURCE -target $PDOC_LOC/$i -raw -webcvs http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/$i/?root=ensembl -xltable $P2WDOC_LOC/$i.xlinks -css_url $CSS_URL" >> $P2WDOC_LOC/make_html_docs.sh
 fi

  echo "$PERLMOD_LOC/$F1 $HTTP/$F1
$PERLMOD_LOC/$F2 $HTTP/$F2
$PERLMOD_LOC/$F3 $HTTP/$F3
$PERLMOD_LOC/$F4 $HTTP/$F4
$PERLMOD_LOC/$F5 $HTTP/$F5
$PERLMOD_LOC/$F6 $HTTP/$F6
$PERLMOD_LOC/$F7 $HTTP/$F7
$PERLMOD_LOC/$F8 $HTTP/$F8
$PERLMOD_LOC/$F9 $HTTP/$F9
$PERLMOD_LOC/$F10 $HTTP/$F10
$PERLMOD_LOC/$F11 $HTTP/$F11
$PERLMOD_LOC/$F12 $HTTP/$F12
" > $P2WDOC_LOC/xlinks.pre
	perl -n -e "print unless m#$PERLMOD_LOC/$i $HTTP/$i#;" < $P2WDOC_LOC/xlinks.pre >$P2WDOC_LOC/$i.xlinks

	echo "echo \"About to tidy-up the html files in $i\"" >> $P2WDOC_LOC/make_html_docs.sh
  echo "perl $PERLMOD_LOC/utils/static_content/pdoc_tidy.pl --dir=$PDOC_LOC/$i" >> $P2WDOC_LOC/make_html_docs.sh
done

chmod 755 $P2WDOC_LOC/make_html_docs.sh
rm $P2WDOC_LOC/xlinks.pre

# Running big pdoc script
echo "Running $P2WDOC_LOC/make_html_docs.sh";
cd $P2WDOC_LOC
./make_html_docs.sh

echo "Deleting generated index $PDOC_LOC/index.html file in favour of cvs version"
cd $PDOC_LOC
rm index.html
cvs -q up 

# cd back into server root directory:
echo "Change back to server root directory";
cd $PERLMOD_LOC


# generate e! docs:
echo "Generating e! docs:";
rm -Rf $PERLMOD_LOC/htdocs/info/docs/webcode/edoc
perl $PERLMOD_LOC/utils/edoc/update_docs.pl
echo "Copying temp files to live directory"
cp -r $PERLMOD_LOC/utils/edoc/temp htdocs/info/docs/webcode/edoc
echo "Clearing up e! docs temp files:";
rm -Rf $PERLMOD_LOC/utils/edoc/temp

exit 0
