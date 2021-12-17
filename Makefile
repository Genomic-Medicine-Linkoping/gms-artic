.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: start \
find_mut \
search_mutations_freebayes \
search_mutations_ivar \
help

CURRENT_CONDA_ENV_NAME = gms-artic
# Note that the extra activate is needed to ensure that the activate floats env to the front of PATH
CONDA_ACTIVATE = source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate ; conda activate $(CURRENT_CONDA_ENV_NAME)

# Change the week number to the same as what is in the Fastq-[week number] directory, e.g.
# if your fastq files are in Fastq-V45, the row below should be NAME = V45
NAME = v48
# Path to gms-artics fastq input files
FASTQS = /data/gms-artic/input/Fastq-$(NAME)


#ARGS = -resume
ARGS = -resume #-process.cpus=90

RES_BASEDIR = results_$(NAME)

# Mutations of interest searching
TEMP_FILE = samples.txt
BCFTOOLS_THREADS = 10
MUTATIONS_DIR = mois

# Genomic coordinates
MoI1 =23012
MoI2 =22813

# In results_v36 should find 3 hits
#MoI1 =4180
# In results_v36 should find 20 hits
#MoI2 =4321

VARIANTS_FILES_FREEBAYES = $(RES_BASEDIR)/ncovIllumina_sequenceAnalysis_callConsensusFreebayes
MoI_OUTFILE_FREEBAYES = $(NAME)_moi_freebayes.tsv
MoI_FREEBAYES = MN908947.3:$(MoI1),MN908947.3:$(MoI2)
FB_SUFFIX = freebayes.vcf
FREEBAYES_QUERY_RESULTS = .variants.norm.$(FB_SUFFIX)

VARIANTS_FILES_IVAR = $(RES_BASEDIR)/ncovIllumina_sequenceAnalysis_callVariants
MoI_OUTFILE_IVAR = $(NAME)_moi_ivar.tsv
MoI_1_ivar = $(MoI1)
MoI_2_ivar = $(MoI2)
IVAR_QUERY_RESULTS = .variants.tsv

STORAGE = /data/gms-artic/results

# Final reports directory
REPORTING_DIRECTORY = AnalysisReport

## start: Remove the previous simg (with possibly older version of pangolin DB) 
## and run gms-artic pipeline
start:
	$(CONDA_ACTIVATE)
	rm -rf work
	nextflow run main.nf -profile singularity --illumina --prefix $(NAME) --directory $(FASTQS) --outdir $(RES_BASEDIR) $(ARGS)
	./bin/joinTables.py \
	$(RES_BASEDIR)/AnalysisReport/$(NAME)/analysisReport.tsv \
	$(RES_BASEDIR)/$(NAME).qc.csv \
	$(RES_BASEDIR)/AnalysisReport/$(NAME)/$(NAME)_fullReport.tsv

# rm -rf work .singularity/genomicmedicinesweden-gms-artic-illumina-latest.img
# singularity cache clean

## find_MoIs: Run searches on mutations of interest on both ivar and freebays output
find_MoIs: search_MoIs_freebayes search_MoIs_ivar
	cp $(RES_BASEDIR)/$(MUTATIONS_DIR)/$(MoI_OUTFILE_FREEBAYES) $(RES_BASEDIR)/$(REPORTING_DIRECTORY)/$(NAME)
	cp $(RES_BASEDIR)/$(MUTATIONS_DIR)/$(MoI_OUTFILE_IVAR) $(RES_BASEDIR)/$(REPORTING_DIRECTORY)/$(NAME)

## search_MoIs_freebayes: Search for substitutions inside FreeBayes vcf results files
## The vcf results files must reside in: results/ncovIllumina_sequenceAnalysis_callConsensusFreebayes (they are so by default)
## or defined in VARIANTS_FILES variable in the CLI, e.g.:
## make search_MoIs_freebayes VARIANTS_FILES=/data/CGL/gms-artic/results_V23/ncovIllumina_sequenceAnalysis_callConsensusFreebayes
##
search_MoIs_freebayes:
	$(CONDA_ACTIVATE)
	(cd $(RES_BASEDIR)
	mkdir -p $(MUTATIONS_DIR)
	rm -f $(MUTATIONS_DIR)/$(MoI_OUTFILE_FREEBAYES))
	(cd $(VARIANTS_FILES_FREEBAYES) \
	&& find . -name "*.variants.norm.vcf" -type f \
	| parallel -N1 -j$(BCFTOOLS_THREADS) "bcftools view --no-header --output-type v --targets $(MoI_FREEBAYES) --threads $(BCFTOOLS_THREADS) --output ../$(MUTATIONS_DIR)/{.}.$(FB_SUFFIX) {}")
	(cd $(RES_BASEDIR)/$(MUTATIONS_DIR) \
	&& find . -empty -type f -delete \
	&& echo '# Results produced by subseting freebayes (https://github.com/freebayes/freebayes) output vcf files using command: "bcftools view --no-header --output-type v --targets MN908947.3:23012,MN908947.3:22813"' > $(MoI_OUTFILE_FREEBAYES) \
	&& if ls *$(FREEBAYES_QUERY_RESULTS) 1> /dev/null 2>&1; then \
	tail -v -n +1 *$(FREEBAYES_QUERY_RESULTS) >> $(MoI_OUTFILE_FREEBAYES); fi
	perl -i -pe "s/_S.*variants.norm.freebayes.vcf <==\n/:/; s/^\n//; s/==> //"  $(MoI_OUTFILE_FREEBAYES) \
	&& rm -f *$(FREEBAYES_QUERY_RESULTS))

## search_MoIs_ivar: Search mutations of interest in ivar output files
search_MoIs_ivar:
	(cd $(RES_BASEDIR)
	mkdir -p $(MUTATIONS_DIR) \
	&& rm -f $(MUTATIONS_DIR)/$(MoI_OUTFILE_IVAR))
	echo '# Results produced by searching ivar (https://andersen-lab.github.io/ivar/html/index.html) variants output files with commands: "grep -P MN908947.3\t$(MoI_1_ivar) *$(IVAR_QUERY_RESULTS)" and "grep -P MN908947.3\t$(MoI_2_ivar) *$(IVAR_QUERY_RESULTS)"\nSAMPLE\tREGION\tPOS\tREF\tALT\tREF_DP\tREF_RV\tREF_QUAL\tALT_DP\tALT_RV\tALT_QUAL\tALT_FREQ\tTOTAL_DP\tPVAL\tPASS\tGFF_FEATURE\tREF_CODON\tREF_AA\tALT_CODON\tALT_AA' > $(RES_BASEDIR)/$(MUTATIONS_DIR)/$(MoI_OUTFILE_IVAR)
	grep -P 'MN908947.3\t'$(MoI_1_ivar) $(VARIANTS_FILES_IVAR)/*$(IVAR_QUERY_RESULTS) >> $(RES_BASEDIR)/$(MUTATIONS_DIR)/$(MoI_OUTFILE_IVAR) || true
	grep -P 'MN908947.3\t'$(MoI_2_ivar) $(VARIANTS_FILES_IVAR)/*$(IVAR_QUERY_RESULTS) >> $(RES_BASEDIR)/$(MUTATIONS_DIR)/$(MoI_OUTFILE_IVAR) || true
	sed -i -e 's%results_v4.*/ncovIllumina_sequenceAnalysis_callVariants/%%' -e 's%_S.*variants.tsv%%' $(RES_BASEDIR)/$(MUTATIONS_DIR)/$(MoI_OUTFILE_IVAR)


## archive: Move to larger storage location and create a symbolic link to it
archive:
	mv $(RES_BASEDIR) $(STORAGE)/$(NAME) \
	&& ln -s $(STORAGE)/$(NAME) $$PWD/$(RES_BASEDIR)

## help: Show this message
help:
	@grep '^##' ./Makefile
