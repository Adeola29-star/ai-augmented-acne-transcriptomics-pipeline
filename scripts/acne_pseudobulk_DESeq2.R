# Install and upload the needed packages

if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install(c("GEOquery", "DESeq2"))
install.packages("Matrix")

library(GEOquery)
library(DESeq2)
library(Matrix)

# Pull the Supplementary files for GSE175817

getwd()

dir.create("C:/bioinformatics_projects/acne_dge", recursive = TRUE, showWarnings = FALSE)

setwd("C:/bioinformatics_projects/acne_dge")

dir.create("data/GSE175817", recursive = TRUE, showWarnings = FALSE)
gse_files <- getGEOSuppFiles("GSE175817", makeDirectory = FALSE, baseDir = "data/GSE175817")

gse_files


# Unpack the raw tar file into individual sample folders

untar("data/GSE175817/GSE175817_RAW.tar", exdir = "data/GSE175817/raw")

# List what is inside

list.files("data/GSE175817/raw")

# Check a donor file before loading all

donor1_preview <- read.csv("data/GSE175817/raw/GSM5348398_donor1.csv.gz", nrows = 5)
dim(donor1_preview)
donor1_preview[, 1:5]

# Check the metadata file

meta_keratinocyte <- read.csv("data/GSE175817/GSE175817_meta_keratinocyte.csv.gz")
head(meta_keratinocyte)

# Check the full column naming pattern in donor 1

donor1_colnames <- colnames(read.csv("data/GSE175817/raw/GSM5348398_donor1.csv.gz", 
                                     nrows = 1))
length(donor1_colnames)
head(donor1_colnames, 20)
table(substr(donor1_colnames, 1, 2))


# Rebuild the function using fread

library(data.table)

process_donor_fast <- function(filepath) {
  donor_data <- fread(filepath)
  gene_names <- donor_data[[1]]
  donor_data[[1]] <- NULL
  is_lesional <- grepl("^L_", colnames(donor_data))
  is_nonlesional <- grepl("^NL_", colnames(donor_data))
  which_lesional <- which(is_lesional)
  which_nonlesional <- which(is_nonlesional)
  lesional_sum <- round(rowSums(donor_data[, ..which_lesional]))
  nonlesional_sum <- round(rowSums(donor_data[, ..which_nonlesional]))
  result <- data.frame(lesional = lesional_sum, nonlesional = nonlesional_sum)
  rownames(result) <- gene_names
  result
}

# Confirm and test on donor1
exists("process_donor_fast")
donor1_result_fast <- process_donor_fast("data/GSE175817/raw/GSM5348398_donor1.csv.gz")
head(donor1_result_fast)

# Run on all six donors and check gene alignment

donor_files <- list.files("data/GSE175817/raw", full.names = TRUE)
all_donor_results <- lapply(donor_files, process_donor_fast)

gene_lists <- lapply(all_donor_results, rownames)
all(sapply(gene_lists, function(g) identical(g, gene_lists[[1]])))

# Combine all six donors into one matrix

pseudobulk_matrix = do.call(cbind, all_donor_results)
colnames(pseudobulk_matrix) <- paste0(rep(paste0("donor", 1:6), each =2),
                                      "_",
                                      rep(c("lesional", "nonlesional"), times =6))

head(pseudobulk_matrix)
dim(pseudobulk_matrix)

# Build the sample metadata table

sample_info <- data.frame(
  donor = rep(paste0("donor", 1:6), each = 2),
  condition = rep(c("lesional", "nonlesional"), times = 6),
  row.names = colnames(pseudobulk_matrix)
)
sample_info

# Build the DESeq2 dataset object

dds <- DESeqDataSetFromMatrix(
  countData = pseudobulk_matrix,
  colData = sample_info,
  design = ~ donor + condition
)
dds

# Run DESeq2

dds_DESeq2 <- DESeq(dds)

# Extract the results for the lesional and nonlesional comparison

res <- results(dds_DESeq2, contrast = c("condition", "lesional", "nonlesional"))
summary(res)

# Extract just the significant genes

res_df <- as.data.frame(res)
res_df$gene <- rownames(res_df)
sig_genes <- res_df[!is.na(res_df$padj) & res_df$padj < 0.05, ]
sig_genes <- sig_genes[order(sig_genes$padj), ]
dim(sig_genes)
head(sig_genes)

# Build volcano plot via ggplot
library(ggplot2)

res_df$category <- "Not significant"
res_df$category[!is.na(res_df$padj) & 
                  res_df$padj < 0.05 & res_df$log2FoldChange > 0] <- "Upregulated in lesional"
res_df$category[!is.na(res_df$padj) & 
                  res_df$padj < 0.05 & res_df$log2FoldChange < 0] <- "Downregulated in lesional"

ggplot(res_df, aes(x = log2FoldChange, y = -log10(pvalue), color = category)) +
  geom_point(alpha = 0.5, size = 1) +
  scale_color_manual(values = c("Upregulated in lesional" = "red", 
                                "Downregulated in lesional" = "blue", 
                                "Not significant" = "grey70")) +
  theme_minimal() +
  labs(title = "Acne Lesional vs. Non-Lesional Skin (Pseudobulk DESeq2)",
       x = "Log2 Fold Change",
       y = "-Log10 P-value",
       color = "")


table(res_df$category)

ggsave("volcano_plot.png", width = 8, height =6, dpi = 300)


# Install pheatmap and prepare the data

install.packages("pheatmap")
library(pheatmap)

top_genes <- head(sig_genes$gene, 30)
norm_counts <- counts(dds_DESeq2, normalized = TRUE)
heatmap_data <- log2(norm_counts[top_genes, ] + 1)

# Build the annotation info and generate the heatmap

annotation_col <- data.frame(
  condition = sample_info$condition,
  row.names = colnames(heatmap_data)
)


png("heatmap_top30.png",
    width = 10,
    height = 8,
    units = "in",
    res = 300)

pheatmap(
  heatmap_data,
  annotation_col = annotation_col,
  cluster_rows = TRUE,
  cluster_cols = TRUE,
  show_rownames = TRUE,
  fontsize_row = 8,
  main = "Top 30 Differentially Expressed Genes: Acne Lesional vs. Non-Lesional"
)

dev.off()


# Setup pathway enrichment(KEGG)

install.packages("BiocManager")
BiocManager::install(c("clusterProfiler", "org.Hs.eg.db"))
library(clusterProfiler)

gene_symbols <- sig_genes$gene
entrez_ids <- bitr(gene_symbols, fromType = "SYMBOL", toType = "ENTREZID",
                   OrgDb = "org.Hs.eg.db")

head(entrez_ids)
nrow(entrez_ids)
length(gene_symbols)

# Run KEGG enrichment

kegg_results <- enrichKEGG(gene = entrez_ids$ENTREZID,
                           organism = "hsa",
                           pvalueCutoff = 0.05)

head(as.data.frame(kegg_results))

# Build the pathway enrichment plot

library(enrichplot)
dotplot(kegg_results, showCategory = 15, title = "KEGG Pathway Enrichment: Acne Lesional
        vs. Non Lesional Skin")

library(ggplot2)
ggsave("kegg_dotplot.png", width = 10, height = 8, dpi = 300)


# Install and load STRINGdb

BiocManager::install("STRINGdb")
library(STRINGdb)

# Setup the STRING database connection

string_db <- STRINGdb$new(version = "12.0", species = 9606,
                          score_threshold = 400, input_directory = "")

# Map your significant genes to STRING's identifiers

sig_genes_for_string <- data.frame(gene = sig_genes$gene)
mapped_genes <- string_db$map(sig_genes_for_string, "gene",
                              removeUnmappedRows = TRUE)
nrow(mapped_genes)

# Get the top hub genes and build the network plot

top_string_genes <- head(mapped_genes, 100)
string_db$plot_network(top_string_genes$STRING_id)

png("string_network_top100.png", width = 20, height = 20, units = "in", res = 300)
string_db$plot_network(top_string_genes$STRING_id)
dev.off()
