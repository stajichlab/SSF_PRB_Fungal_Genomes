Subsurface Fungi from Power River Basin
========================================

Genome annotation and analysis for Subsurface Fungi isolated from in situ incubation of coal fragments in deep wells at Powder River Basi
n.

Cultured by Quinn Moon (U Michigan)

Authors
-------
Jason Stajich
Quinn Moon
Tim James


Genome assembly and annotation pipeline for 5 fungal isolates (Ascomycota) recovered from Powder River Basin.
Part of the CIFAR Fungl Kingdom / Earth 4D project.

## Samples

Defined in `samples.csv` (11-column, comma-delimited):

| Column | Description |
|--------|-------------|
| ID | Sample identifier; used as stem for all input/output filenames |
| FileBase | Base filename (typically same as ID) |
| SRARun | NCBI SRA accession (if applicable) |
| Species | Species name |
| Strain | Strain designation |
| TaxonID | NCBI taxonomy ID (used by FCS-GX contamination screen) |
| LocusTag | Locus tag prefix for annotation |
| BioProject | NCBI BioProject accession |
| BioSample | NCBI BioSample accession |
| BUSCO | BUSCO lineage database for this sample (e.g. `sordariomycetes_odb10`) |
| Notes | Free text; samples marked `Too Low` are skipped in assembly |

Illumina reads expected at `input/illumina/${ID}_R1.fastq.gz` and `input/illumina/${ID}_R2.fastq.gz`.

## Pipeline Overview

All steps are SLURM batch scripts. Per-sample scripts use SLURM array jobs where N is the 1-based row index in `samples.csv` (excluding the header):

```bash
# Array job
sbatch --array=1-5 pipeline/asm/01_AAFTF.sh

# Single sample (interactive)
bash pipeline/asm/01_AAFTF.sh 2

# All-samples-at-once (no array)
sbatch pipeline/asm/02_clean_fcsgx.sh
```

Logs are written to `logs/`.

### Assembly (`pipeline/asm/`)

| Script | Input | Output | Notes |
|--------|-------|--------|-------|
| `01_AAFTF.sh` | `input/illumina/${ID}_R[12].fastq.gz` | `asm/AAFTF/${ID}.vecscreen.fasta` | Trim (fastp→bbduk), filter, SPAdes assembly, FCS adaptor screen |
| `02_clean_fcsgx.sh` | `asm/AAFTF/${ID}.vecscreen.fasta` | `asm/AAFTF/${ID}.fcs_gx.fasta` | NCBI FCS-GX contamination purge; requires 500 GB RAM; loads DB to `/dev/shm` |
| `03_AAFTF_finish.sh` | `asm/AAFTF/${ID}.fcs_gx.fasta` | `asm/AAFTF/${ID}.sorted.fasta` | Remove duplicates, POLCA polish, sort contigs, assembly stats |

Working SPAdes files go to `working_AAFTF/`; intermediate trimmed reads are cleaned up after assembly completes.

### Annotation (`pipeline/annotation/`)

| Script | Tool | Notes |
|--------|------|-------|
| `01_mask.sh` | RepeatModeler + RepeatMasker | Builds custom repeat library; input genome from `genomes/${ID}.sorted.fasta` |
| `02_RNAseq_train.sh` | funannotate train / PASA | RNA-seq training; not applicable for current samples (no RNA) |
| `03_predict.sh` | funannotate predict | Augustus gene prediction; uses per-sample `BUSCO` lineage and `aspergillus_fumigatus` as seed species |
| `04_update.sh` | funannotate update | PASA-based UTR/model update; requires MySQL via `000_start_mysql.sh` |
| `05a_antismash_local.sh` | antiSMASH | Secondary metabolite cluster prediction |
| `05b_iprscan.sh` | InterProScan | Protein domain annotation |
| `06_annotate_function.sh` | funannotate annotate | Integrates InterProScan + antiSMASH results, assigns functional annotations |

`000_start_mysql.sh` — starts a MariaDB instance via Singularity for PASA; must be running before steps 02 and 04.

### Stats / QC (`pipeline/stats/`)

- `01_asm_stats.sh` — AAFTF assembly statistics
- `02_find_telomeres.sh` — telomere detection across all genomes in `genomes/`
- `03_BUSCO.sh` — BUSCO completeness (iterates over files in `genomes/`, not via sample array)
- `04_read_count.sh` / `04_read_count_ONT.sh` / `04_read_count_minimap.sh` — read mapping coverage (template scripts; internal paths reference long-read workflow and need updating for this project)

### Polish and Scaffold (`pipeline/polish/`, `pipeline/scaffold/`)

These are template scripts carried over from a long-read (Nanopore + Canu/Flye) workflow. The `samples.csv` reading has been updated to use the current 11-column format, but the internal logic (file paths referencing `canu`, `flye`, `$NANOPORE`, etc.) needs to be adapted before use with this project.

### Comparative (`pipeline/comparative/`)

`00_init.sh` — sets up a `Comparative/` directory, links to `Comparative_pipeline`, and launches OrthoFinder and domain annotation jobs. Requires annotation to be complete.

## Key Environment Details

- **Cluster**: UCR HPCC (SLURM); software loaded via `module load`
- **AAFTF_DB**: `/bigdata/stajichlab/shared/lib/AAFTF_DB`
- **FUNANNOTATE_DB**: `/bigdata/stajichlab/shared/lib/funannotate_db`
- **FCS-GX DB**: `/srv/projects/db/ncbi-fcs/0.5.4/gxdb` (rsync'd to `/dev/shm` at runtime by `02_clean_fcsgx.sh`)
- **Augustus config**: `lib/augustus/3.5.0/config` (local copy to avoid permission issues)
- AAFTF >= 0.3.1 required

## Directory Structure

```
input/illumina/        Illumina read pairs
asm/AAFTF/             Assembly working files and intermediate outputs
genomes/               Final sorted/masked genome FASTA files
library/repeat_library/ RepeatModeler output libraries
RepeatModeler_run/     RepeatModeler working directories
RepeatMasker_run/      RepeatMasker output
annotation/            funannotate annotation directories
logs/                  SLURM job logs
working_AAFTF/         SPAdes temporary working files
lib/                   Local config (Augustus, SBT templates, NextPolish cfg)
```
