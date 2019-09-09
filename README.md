# Format_NCBI_QIIME
Method for creating QIIME-compatible taxonomic databases from any subset of NCBI data. 

The UNITE database is really great… as long as you are looking for ectomycorrhizal fungi in Northern Europe.
We recently came to terms with how bad it can be for other ecosystems when analyzing ITS reads from mesophotic coral sites. When you assign taxonomy to your OTUs, you are constrained by the thoroughness and appropriateness your database. When sequencing environmental samples, in addition to fungi, your primers may be amplifying ITS regions from a plant host, weird insects, corals, etc.. These reads are clustered just like any other when you are picking OTUs, but when it comes time to assign them a taxonomy, QIIME will attempt to smash them into one of the bins allowed by your reference database.  This problem is compounded when you are looking at understudied systems where lots of novel fungal taxa might be expected.
You will wind up with taxonomic assignments that simply do not reflect reality.
