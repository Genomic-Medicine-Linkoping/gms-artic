#!/usr/bin/env python3
import pandas as pd
import sys

# Read files
pangolinTyping=pd.read_csv(sys.argv[1], sep='\t')
qc=pd.read_csv(sys.argv[2])

# Clean column contents
#pangolinTyping['taxon'] = pangolinTyping['taxon'].replace(regex=True, to_replace="Consensus_", value="")
pangolinTyping['taxon'] = pangolinTyping['taxon'].replace(regex=True, to_replace="_S\d+_L001\.primertrimmed\.consensus_threshold_0\.75_quality_20", value="")
pangolinTyping.rename(columns={'taxon':'sample_name'}, inplace=True)
qc['sample_name'] = qc['sample_name'].replace(regex=True, to_replace="_S\d+_L001", value="")

# Merge tables
df=pangolinTyping.merge(qc,
                        on='sample_name', 
                        how='left', 
                        suffixes=("","_qc"))

# Write to a file
df.to_csv(sys.argv[3], sep='\t', index=False)
