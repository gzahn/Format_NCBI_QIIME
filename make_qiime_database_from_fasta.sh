#!/bin/sh

# this script takes a fasta file and creates a QIIME-compatible database for OTU-picking and taxonomic assignment
# This script comes with no guarantees. Use at your own peril.


# Usage: bash make_qiime_database_from_fasta.sh /ABS/PATH/TO/INPUT_FASTA_FILE /ABS/PATH/TO/DIRECTORY/FOR/entrez_qiime.py /ABS/PATH/TO/NCBI/TAXONOMY/DIRECTORY/ 	/ABS/PATH/TO/OUTPUT/DIRECTORY/


# It is useful for taking the results of an Entrez NCBI query and turning them into a database, and was developed due to the limitations of the UNITE fungal database currently in use in QIIME, but can be used with any fasta file
# For example, you may want to build a database from all the ITS sequences available from NCBI between a certain length. To do this, simply execute an entrez search, download the resulting output, and feed it into this script.

# This script assumes you have a local copy of entrez_qiime.py on your machine, available here: https://raw.githubusercontent.com/bakerccm/entrez_qiime/master/entrez_qiime.py

# This script also asumes you have a local copy of the NCBI taxonomy database on your machine, obtainable as follows:


### Download NCBI names and taxonomy information (check md5sums to ensure proper downloads) ###

#######################

#accession_to_taxid
# ftp ftp://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
# gunzip nucl_gb.accession2taxid.gz

#taxdump
# ftp ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
# tar -zxvf taxdump.tar.gz

# I prefer wget since ftp did not work for me?
# wget ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
# wget ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
# 


#######################

# If you don't have ENTREZ on your machine, install it as follows:

# ###  install EDirect on your local machine:  ###

#######################

#cd ~
#perl -MNet::FTP -e \
#  '$ftp = new Net::FTP("ftp.ncbi.nlm.nih.gov", Passive => 1);
#   $ftp->login; $ftp->binary;
#   $ftp->get("/entrez/entrezdirect/edirect.zip");'
# above can be easyily done with 
# wget wget ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/edirect.zip
#unzip -u -q edirect.zip
#rm edirect.zip
#export PATH=$PATH:$HOME/edirect
#./edirect/setup.sh

#echo "export PATH=\$PATH:\$HOME/edirect" >> $HOME/.bash_profile
#exec bash

#######################

# you can now execute a search of the NCBI database.  for example:

# esearch -db nuccore -query "\"\(internal transcribed spacer 1\"[All Fields] AND \(300[SLEN] : 600[SLEN]\)\) NOT \"uncultured Neocallimastigales\"[porgn] NOT \"bacteria\"[Filter]" \| efetch -format fasta -mode text > ./Desktop/NCBI_ITS1_DB_raw.fasta

# I think you escaped the pipe by accident?  Also not eveyone has ./Desktop
# esearch -db nuccore -query "\"\(internal transcribed spacer 1\"[All Fields] AND \(300[SLEN] : 600[SLEN]\)\) NOT \"uncultured Neocallimastigales\"[porgn] NOT \"bacteria\"[Filter]" | efetch -format fasta -mode text > ~/NCBI_ITS1_DB_raw.fasta
# this downloads fasta with ALL ncbi seqs of ITS1 between 300:600 bp, that aren't bacterial or "uncultured gut fungi" (416,912 sequences as of Dec 16, 2016) and saves them as s fasta text file 
#depending on size of query results, this can take some time, so be careful about hangups and make sure your connection is good


#######################


###  Search for and remove any empty sequences ###
gawk 'BEGIN {RS = ">" ; FS = "\n" ; ORS = ""} {if ($2) print ">"$0}' $1 > $1.tidy


# Obtain NCBI taxonomy lineages for your input fasta
python $2entrez_qiime.py -i $1.tidy -o $4NCBI_Taxonomy.txt -r kingdom,phyllum,class,order,family,genus,species -a $3nucl_gb.accession2taxid -n $3


### Validate and Tidy up files ###

### Edit output file to include rank IDs (QIIME needs them for some scripts)
cat $4/NCBI_Taxonomy.txt | sed 's/\t/\tk__/' | sed 's/;/>p__/' | sed 's/;/>c__/' | sed 's/;/>o__/' | sed 's/;/>f__/' | sed 's/;/>g__/' | sed 's/;/>s__/' | sed 's/>/;/g' > $4NCBI_QIIME_Taxonomy.txt

### Edit database to single-line fasta format
awk '/^>/ {printf("\n%s\n",$0);next; } { printf("%s",$0);}  END {printf("\n");}' < $1.tidy > $1.tidy.oneline.fasta

### Remove first blank line
sed -i '/^$/d' $1.tidy.oneline.fasta

### Remove trailing descriptions after Accession No.
sed -i 's/ .*//' $1.tidy.oneline.fasta

### compare read counts in fasta and txt files
grep -c "^>" $1.tidy.oneline.fasta
wc -l $4/NCBI_QIIME_Taxonomy.txt

#if numbers are different, there are duplicates introduced by entrez_qiime.py

### if some duplicates may appear in fasta file (i.e., more reads than taxonomy IDs), get lists of Seq/Taxonomy IDs and remove duplicates from fasta file

cut -f 1 $4/NCBI_QIIME_Taxonomy.txt > Tax_Names
grep "^>" $1.tidy.oneline.fasta | cut -d " " -f 1 | sed 's/>//g' > $4/DB_Names
sort $4/DB_Names | uniq -d > $4/Duplicated_IDs
grep -A1 -f $4/Duplicated_IDs $1.tidy.oneline.fasta | sed '/^--/d' > $4/Duplicated_fastas
for fn in $4/Duplicated_fastas; do count=$(wc -l <"$fn"); half=$(($count/2 )); head -n $half $fn > $4/add_back; done
grep -v -f $4/Duplicated_IDs $1.tidy.oneline.fasta > $4/tidy.no_reps.fasta
cat $4/tidy.no_reps.fasta $4/add_back > $4/DB_raw.fasta

### Sort fasta database to same order as taxonomy map

echo "Sorting Database...This will take some time."

cut -f 1 $4/NCBI_QIIME_Taxonomy.txt > $4/IDs_in_order.txt
while read ID ; do grep -m 1 -A 1 "^>$ID" $4/DB_raw.fasta ; done < $4/IDs_in_order.txt > $4/DB.fasta  #This will take quite a long time to run

mv $4/NCBI_QIIME_Taxonomy.txt $4/Taxonomy.txt

rm $4/DB_Names $4/DB_raw.fasta $4/Duplicated_fastas $4/Duplicated_IDs $4/IDs_in_order.txt $4/NCBI_Taxonomy.txt $4/Tax_Names $4/tidy.no_reps.fasta $1.tidy.oneline.fasta $1.tidy $4/add_back

cat $1.log

grep "^>" $4/DB.fasta | sed 's/>//' >$4/good_acc_list

echo "Cleaning Taxonomy to match Database...This may take some time."

while read ID ; do grep -m 1 $ID $4/Taxonomy.txt ; done < $4/good_acc_list > $4/Taxonomy_ordered.txt
#mv $4/Taxonomy_ordered.txt $4/Taxonomy.txt
#rm $4/good_acc_list

grep "k__NA;p__NA;c__NA;o__NA;f__NA;g__NA;s__NA\|^:" $4/Taxonomy_ordered.txt | cut -f1 > bad_acc_list



sed -e '/k__NA;p__NA;c__NA;o__NA;f__NA;g__NA;s__NA/d' $4/Taxonomy_ordered.txt > $4/Taxonomy_clean1.txt
sed -e '/^:/d' $4/Taxonomy_clean1.txt > $4/Taxonomy.txt

echo "Final cleanup to remove bad accessions..."

while read bad; do echo "Removing $bad" ; sed -i -e "/$bad/,+1d" $4/DB.fasta ; done < bad_acc_list
sed -i -e '/^>:/,+1d' $4/DB.fasta


grep "^>" $4/DB.fasta | sed 's/>//' > $4/DB_IDs_ordered
while read ID; do grep $ID $4/Taxonomy_ordered.txt ; done < $4/DB_IDs_ordered > Taxonomy_final.txt


rm $4/Taxonomy_clean1.txt $4/Taxonomy_ordered.txt
mv bad_acc_list bad_acc_list.txt


echo -e "Process complete. Final database is DB_ordered.fasta, and associated taxonomy is Taxonomy_ordered.txt\nAccessions that were removed are in bad_acc_list.txt"

