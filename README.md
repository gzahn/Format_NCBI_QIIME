# Format_NCBI_QIIME
Method for creating QIIME-compatible taxonomic databases from any subset of NCBI data. 

The UNITE database is really great… as long as you are looking for ectomycorrhizal fungi in Northern Europe.
When you assign taxonomy to your OTUs, you are constrained by the thoroughness and appropriateness your database. When sequencing environmental samples, in addition to fungi, your primers may be amplifying ITS regions from a plant host, weird insects, corals, etc.. These reads are clustered just like any other when you are picking OTUs, but when it comes time to assign them a taxonomy, QIIME will attempt to smash them into one of the bins allowed by your reference database.  This problem is compounded when you are looking at understudied systems where lots of novel fungal taxa might be expected.

**You will wind up with taxonomic assignments that simply do not reflect reality.**
For example, I've noticed coral ITS1 reads being unambiguously assigned to fungal taxa when using just UNITE.

One obvious solution is to add some meaningful outgroups to the UNITE database so that the taxonomic assignment algorithm has some place for your reads to go if it can't find a good match in UNITE's species hypotheses.

I’ll demonstrate one way of making your own customized NCBI database that is compatible with QIIME.  This is just one way of dealing with the shortcomings of the UNITE database, and it may not be best for your data.
The basic steps to making your own QIIME-compatible database:

**1) Design a query to extract the sequences you want to include in your database from NCBI**

**2) Download all the NCBI names and taxonomy information**

**3) Create a database that links sequence IDs to taxonomic information that QIIME can parse**

**4) Clean up the files and validate them**

__________
**The first step is to make sure you have ENTREZ Direct installed on your machine.  This is a tool from NCBI that allows you to query the NCBI database remotely from the command line.**
```BASH{}
###  install EDirect on your local machine:  ###

cd ~
perl -MNet::FTP -e \
  '$ftp = new Net::FTP("ftp.ncbi.nlm.nih.gov", Passive => 1);
   $ftp->login; $ftp->binary;
   $ftp->get("/entrez/entrezdirect/edirect.zip");'
unzip -u -q edirect.zip
rm edirect.zip
export PATH=$PATH:$HOME/edirect
./edirect/setup.sh

echo "export PATH=\$PATH:\$HOME/edirect" >> $HOME/.bash_profile
exec bash
```


Now we can design a query that will scour NCBI and pull only the records that we want to include in our database.  There is a slight learning curve to figuring out how to “word” your query, so I recommend going onto the NCBI ENTREZ search page and playing with the filters and search terms to see how to “phrase things.” 

Once you have a search you like, you can see the exact search terms in the bottom right of the results page. For my query, I wanted to pull all the “complete” (between 300 and 600 bp) ITS1 reads that didn’t come up as a random unknown gut fungus (There are  LOT of these in NCBI thanks to the daily barrage of gut metagenome papers coming out).

This search string looks like this:
(“internal transcribed spacer 1″[All Fields] AND (“300″[SLEN] : “600”[SLEN])) NOT “uncultured Neocallimastigales”[porgn] NOT “bacteria”[Filter]

. . . And to use it in EDirect, it looks like this (note the character escapes before crucial quotes):

```BASH{}
esearch -db nuccore -query "\"\(internal transcribed spacer 1\"[All Fields] AND \(300[SLEN] : 600[SLEN]\)\) NOT \"uncultured Neocallimastigales\"[porgn] NOT \"bacteria\"[Filter]" \
 | efetch -format fasta -mode text > ./Desktop/NCBI_ITS1_DB_raw.fasta

# this downloads fasta with ALL ncbi seqs of ITS1 between 300:600 bp, that aren't bacterial or "uncultured gut fungi" (416,912 sequences as of Dec 16, 2016) and saves them as s fasta text file called "NCBI_ITS1_DB.fasta"
#depending on size of query results, this can take some time, so be careful about hangups and make sure your connection is good
```

Okay, now since NCBI has all kinds of crazy uncurated data, we need to look for empty sequences before proceeding, as these will cause major problems down the line.  You can find and remove these really quickly with awk:

```BASH{}
###  Search for and remove any empty sequences ###
awk 'BEGIN {RS = ">" ; FS = "\n" ; ORS = ""} {if ($2) print ">"$0}' NCBI_ITS1_DB_raw.fasta > NCBI_ITS1_DB.fasta
```
_____

**Now that we have the sequences we want, the second step is to download all of the NCBI names and taxonomic information**
Note: you could use wget, curl, or whatever you want to download these files...
```BASH{}
### Download NCBI names and taxonomy information (check md5sums to ensure proper downloads) ###

#accession_to_taxid
 ftp ftp://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
 gunzip nucl_gb.accession2taxid.gz

#taxdump
 ftp ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
 tar -zxvf taxdump.tar.gz

#files_to_keep = nodes.dmp, names.dmp, merged.dmp and delnodes.dmp
 rm citations.dmp division.dmp gc.prt gencode.dmp
 ```
 ______

**Now we should be ready to format the database for use in QIIME. I played around with clumsy ways of doing this, but the fastest and simplest is a script by Christopher Baker named entrez_qiime.py**

See his work here [https://github.com/bakerccm/entrez_qiime]

```BASH{}
# note that absolute filepaths are necessary or the script may return an error

python enterz_qiime.py -i ABSOLUTE_PATH/NCBI_ITS1_DB.fasta -o ABSOLUTE_OUTPUT_PATH/NCBI_ITS1_Taxonomy.txt -r kingdom,phyllum,class,order,family,genus,species
```

______

**The entrez_qiime.py script is super fast and easy, but your files will probably need a lot of grooming or QIIME will act very rudely.  Here are the steps that were needed to prepare my files:**

```BASH{}
### Validate and Tidy up files ###

### Edit output file to include rank IDs (QIIME needs them for some scripts)
cat NCBI_ITS1_Taxonomy.txt | sed 's/\t/\tk__/' | sed 's/;/>p__/' | sed 's/;/>c__/' | sed 's/;/>o__/' | sed 's/;/>f__/' | sed 's/;/>g__/' | sed 's/;/>s__/' | sed 's/>/;/g' > NCBI_ITS1_QIIME_Taxonomy.txt

### Edit database to single-line fasta format
awk '/^>/ {printf("\n%s\n",$0);next; } { printf("%s",$0);}  END {printf("\n");}' < NCBI_ITS1_DB.fasta > NCBI_ITS1_QIIME_DB.fasta

### Remove first blank line
sed -i '/^$/d' NCBI_ITS1_QIIME_DB.fasta

### Remove trailing descriptions after Accession No.
sed -i 's/ .*//' NCBI_ITS1_QIIME_DB.fasta

### compare read counts in fasta and txt files
grep -c "^>" NCBI_ITS1_QIIME_DB.fasta
wc -l NCBI_ITS1_QIIME_Taxonomy.txt

#if numbers are different, there are duplicates introduced by entrez_qiime.py

### if some duplicates may appear in fasta file (i.e., more reads than taxonomy IDs), get lists of Seq/Taxonomy IDs and remove duplicates from fasta file

cut -f 1 NCBI_ITS1_QIIME_Taxonomy.txt > Tax_Names
grep "^>" NCBI_ITS1_QIIME_DB.fasta | cut -d " " -f 1 | sed 's/>//g' > DB_Names
sort DB_Names | uniq -d > Duplicated_IDs
grep -A1 -f Duplicated_IDs NCBI_ITS1_QIIME_DB.fasta | sed '/^--/d' > Duplicated_fastas
for fn in Duplicated_fastas; do count=$(wc -l <"$fn"); half=$(($count/2 )); head -n $half $fn > add_back; done
grep -v -f Duplicated_IDs NCBI_ITS1_QIIME_DB.fasta > NCBI_ITS1_QIIME_DB.no.reps.fasta
cat NCBI_ITS1_QIIME_DB.no.reps.fasta add_back > NCBI_ITS1_QIIME_DB.fasta

### Sort fasta database to same order as taxonomy map

cut -f 1 NCBI_ITS1_QIIME_Taxonomy.txt > IDs_in_order.txt
while read ID ; do grep -m 1 -A 1 "^>$ID" NCBI_ITS1_QIIME_DB.fasta ; done < IDs_in_order.txt > NCBI_ITS1_QIIME_DB.fasta.sorted &  #This will take quite a long time to run
```

______

Now these files should be ready to use for OTU Picking just like the UNITE Reference and Taxonomy files!
You can tailor your NCBI query to find the reads you want and design your own custom database using this same workflow.

**Probably the best use of this workflow is to tailor an NCBI query to pull sequences from likely outgroups in your study and concatenate these onto the ends of the UNITE database files.**
