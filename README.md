# AI-Augmented Acne Transcriptomics Pipeline

## Problem

Acne vulgaris is an inflammatory skin condition involving changes in immune activity, epidermal biology, and tissue structure. Understanding the genes and biological pathways that differ between acne lesions and non-lesional skin can provide insight into the molecular processes associated with the disease.

Publicly available acne transcriptomic datasets are relatively limited, particularly datasets containing suitable paired samples for differential expression analysis. This project therefore uses a publicly available single-cell RNA-seq dataset and aggregates the cell-level counts to the donor level to create pseudobulk samples.

The analysis compares lesional and non-lesional skin from the same six acne patients, allowing differences between individual donors to be accounted for during differential expression analysis.

## Approach

### 1. Dataset

The analysis uses GSE175817 from the NCBI Gene Expression Omnibus (GEO).

The dataset contains 10X Genomics single-cell RNA-seq data from six acne patients, with lesional and non-lesional skin samples available for each donor.

**Why single-cell data, and why not a microarray dataset:** well-established public acne datasets such as GSE108110 are microarray data rather than RNA-seq, meaning they report probe intensities rather than sequencing read counts. DESeq2 is designed for count-based RNA-seq data, using a negative binomial model and size-factor normalisation. Rather than applying DESeq2 inappropriately to microarray intensities, this project uses sequencing-based single-cell data and aggregates it into donor-level pseudobulk samples. This provides count data suitable for DESeq2 while retaining the paired acne-lesion design.

Rather than treating individual cells as independent biological replicates, cells were aggregated within each donor and condition to generate donor-level pseudobulk samples. This avoids pseudo-replication, where thousands of cells from the same individual would otherwise be incorrectly treated as independent biological replicates, which is a well-documented statistical pitfall in single-cell differential expression (Squair et al., 2021, *Nature Communications*, "Confronting false discoveries in single-cell differential expression").

This produced:
- 6 donors
- 2 conditions per donor
- 12 pseudobulk samples
- approximately 29,000 genes

### 2. Pseudobulk preparation

For each donor, lesional and non-lesional cell counts were identified from the supplied count matrices.

Counts were summed separately across cells for each condition, producing one lesional and one non-lesional pseudobulk sample per donor.

### 3. Differential expression analysis

Differential expression analysis was performed using DESeq2.

The experimental design was:

```
~ donor + condition
```

Including donor in the design accounts for the paired nature of the samples while testing the effect of lesional versus non-lesional condition.

Genes were considered significantly differentially expressed using an adjusted p-value < 0.05.

### 4. Visualisation

The differential expression results were visualised using a volcano plot and a heatmap of the top 30 significant genes (by adjusted p-value).

### 5. Pathway enrichment

Significant genes were converted to Entrez Gene IDs and analysed using KEGG pathway enrichment with clusterProfiler.

### 6. Protein interaction analysis

Significant genes were also analysed using STRINGdb to investigate known and predicted protein-protein interactions.

### 7. Classification (AI layer)

To extend this analysis with a machine learning component, a logistic regression classifier was trained to predict lesional versus non-lesional status directly from gene expression. See "Classifier: Predicting Condition from Expression" below.

### 8. AI-assisted biological interpretation

The KEGG enrichment results were also given to an AI assistant to draft a plain-English interpretation, which was then reviewed and corrected against the actual biology. See "AI-Assisted Interpretation" below.

## Results

The analysis identified **1,879 significantly differentially expressed genes** between lesional and non-lesional skin at adjusted p-value < 0.05: 882 upregulated and 997 downregulated in lesional skin.

### Differential expression

The volcano plot demonstrated substantial transcriptional differences between lesional and non-lesional skin.

![Volcano plot of differentially expressed genes](volcano_plot.png)

The heatmap of the top 30 significant genes (selected by lowest adjusted p-value) showed some clustering by condition. Donors 4, 5, and 6 grouped clearly by lesional/non-lesional status, but the separation was not complete across all donors. Donor 3's two samples clustered adjacent to each other rather than with their respective condition groups. See Limitations for discussion.

![Heatmap of top 30 differentially expressed genes](heatmap_top30.png)

### KEGG pathway enrichment

The analysis identified several enriched biological pathways associated with the differences between acne lesional and non-lesional skin.

**Top enriched pathways:**

1. **Cornified envelope formation** - 49 genes, adjusted p-value ≈ 1.9 × 10⁻⁶
2. **Staphylococcus aureus infection** - 26 genes, adjusted p-value ≈ 1.9 × 10⁻⁴
3. **Lysosome biogenesis** - 46 genes, adjusted p-value ≈ 9.0 × 10⁻⁴
4. **Cell cycle** - 33 genes, adjusted p-value ≈ 9.0 × 10⁻⁴
5. **p53 signaling pathway** - 19 genes, adjusted p-value ≈ 3.6 × 10⁻³
6. **Tight junction** - 32 genes, adjusted p-value ≈ 7.7 × 10⁻³
7. **PI3K-Akt signaling pathway**
8. **Efferocytosis**
9. **Integrin signaling**
10. **Hippo signaling pathway**
11. **ECM-receptor interaction**
12. **Complement and coagulation cascades**
13. **Pertussis**
14. **Mineral absorption**
15. **Bladder cancer**

Cornified envelope formation was the single most statistically significant enriched pathway in this analysis, with an adjusted p-value of approximately 1.9 × 10⁻⁶.

[KEGG pathway enrichment dotplot](kegg_dotplot.png)

*Note: pathways in this plot are ordered by GeneRatio (proportion of significant genes involved in each pathway), not by statistical significance. Cornified envelope formation has the lowest adjusted p-value overall, despite PI3K-Akt signaling appearing first by gene count.*


![KEGG pathway enrichment dotplot](kegg_dotplot.png)

*Note: pathways in this plot are ordered by GeneRatio (proportion of significant genes involved in each pathway), not by statistical significance. Cornified envelope formation has the lowest adjusted p-value overall, despite PI3K-Akt signalling appearing first by gene count.*

### STRING protein interaction analysis

The STRING network of the top 100 significant genes contained 140 observed interactions versus ~33 expected (p < 0.001), indicating significant network enrichment.

A prominent immune/macrophage-associated cluster included CD163, FCGR3A, C1QB, LILRB1, LILRB2, LILRB4, C3AR1, C5AR1, CCR1, and GZMB.

A separate extracellular matrix/tissue structure cluster included COL4A1, COL4A2, COL4A4, LAMB1, PLOD1, and EMILIN1.

![STRING protein-protein interaction network](string_network_top100.png)

## Comparison to the Original Study

GSE175817 was generated for Do et al. (2022), *"TREM2 macrophages induced by human lipids drive inflammation in acne lesions,"* published in *Science Immunology*. The original study's central finding, derived from cell-type-resolved single-cell and spatial analysis, was that a specific macrophage subtype (**TREM2⁺ macrophages**) accumulates near hair follicles and sebaceous glands in acne lesions. These macrophages are induced by **squalene**, a skin lipid overproduced in acne, which drives their differentiation while simultaneously impairing their ability to kill *Cutibacterium acnes*, resulting in a self-perpetuating cycle of lipid accumulation and inflammation.

**Convergence with this analysis.** The dominant cluster identified in this project's STRING network (CD163, FCGR3A, C1QB, LILRB1/2/4, C3AR1, C5AR1, CCR1, GZMB) is macrophage/myeloid-dominated independently arriving at macrophages as the central cell type of interest, despite using a different analytical approach (bulk pseudobulk differential expression and network analysis, rather than the original study's cell-type-specific subclustering). Two independent methods converging on the same cell type is a meaningful consistency check.

**A connection anticipated before reviewing the source paper.** This project's AI-Assisted Interpretation section (see below) independently proposed that lysosome pathway enrichment might reflect sebocyte lipid processing rather than purely immune debris clearance. The original study's central mechanism; squalene-driven lipid metabolism in macrophages, directly supports that earlier speculation.

**An honest divergence.** This project's single strongest statistical signal was cornified envelope formation (epidermal barrier biology), whereas the original study's central narrative concerns the macrophage-lipid-bacterial axis specifically, with less emphasis on keratinocyte barrier function. This is a plausible consequence of methodology rather than a contradiction as this analysis used pseudobulk aggregation, summing expression across *all* cell types combined, while the original study deliberately isolated and compared macrophage subpopulations. Keratinocytes are far more numerous than macrophages in skin tissue, so a pseudobulk approach could allow epidermal signal to dominate the top statistical results even where a specific immune cell subtype shows the most disease-relevant biology. 

## Interpretation

**1. Epidermal and barrier biology.** The enrichment of cornified envelope formation and tight junction pathways suggests alterations in epidermal differentiation and skin-barrier function relevant to acne given the epidermis's role as a physical barrier, and given that altered keratinisation is thought to contribute to pore blockage.

**2. Immune-associated activity.** The STRING network's macrophage/immune gene cluster is consistent with increased immune-associated transcriptional signatures in acne lesions. However, because this analysis uses all-cell pseudobulk data, it cannot distinguish whether individual cells show increased expression versus whether differences in cell-type composition between conditions drive the signal.

**3. Tissue structure and remodelling.** Extracellular matrix genes (COL4A1, COL4A2, LAMB1, PLOD1) and related pathway enrichment suggest active tissue remodelling in lesional skin.

Together, these results point to a combination of altered epidermal/barrier biology, immune activity, and extracellular matrix remodelling in acne lesions, rather than inflammation alone.

## Classifier: Predicting Condition from Expression

As an additional machine learning component, a logistic regression classifier was trained to predict lesional versus non-lesional status directly from gene expression, using Leave-One-Out Cross-Validation (LOOCV) which is the appropriate evaluation method given the small sample size (n = 12), where a conventional train/test split would be uninformative.

**Initial approach and a data leakage issue.** An initial version selected the top 30 genes (by DESeq2 adjusted p-value) using the full 12-sample dataset, then evaluated a classifier on those same 30 genes with LOOCV. This produced a suspicious 100% accuracy (12/12). This was identified as **data leakage**: because gene selection used all 12 samples including whichever sample was later "held out" for testing in each LOOCV fold has no test sample was ever genuinely unseen during feature selection.

**Corrected approach.** This was fixed by building a single scikit-learn `Pipeline` combining feature selection (`SelectKBest`, top 30 genes by ANOVA F-test) and classification (logistic regression), so that gene selection was performed independently within each of the 12 LOOCV folds, using only that fold's 11 training samples. The held-out sample never influenced which genes were selected.

**Corrected result: 66.7% accuracy (8/12 correct).** This exceeds the 50% chance baseline for this balanced two-class problem and indicates that the expression data contains some predictive information, although the estimate is highly uncertain given the small sample size.

**Misclassification pattern.** Four of the twelve samples were misclassified: both of donor 1's samples (lesional and non-lesional), donor 3's non-lesional sample, and donor 5's lesional sample. Donor 1 having both samples misclassified suggests that donor's overall expression baseline may be atypical relative to the other donors, independent of condition. Donor 3's misclassification is notable for a separate reason: donor 3 was also the donor whose samples failed to cluster cleanly by condition in the heatmap above, an independent line of evidence from unsupervised clustering pointing to the same donor.

**This result should be read as a proof of concept, not a well-supported finding.** With only 12 samples, each individual correct or incorrect prediction shifts overall accuracy by roughly 8.3 percentage points, making the LOOCV estimate inherently high-variance. A larger cohort would be needed to draw confident conclusions about how predictive this expression signature genuinely is.

## AI-Assisted Interpretation

To draft an accessible, non-specialist interpretation of the KEGG pathway results, the enriched pathway list was given to an AI assistant with the following prompt: *"I ran KEGG pathway enrichment analysis comparing acne-lesional vs. non-lesional skin using RNA-seq data. Here are my top enriched pathways [list as shown in the KEGG pathway section]. Can you explain in plain English, for a non-specialist reader, what these pathways suggest is happening biologically in acne-affected skin?"*

### AI-drafted interpretation (unedited)

> Here's what this pathway signature is telling you, translated into plain English:
>
> **The skin barrier is under construction (and struggling).** "Cornified envelope formation" is the single strongest signal here, by a wide margin. This is the pathway that builds the tough outer layer of skin cells (the stratum corneum) — the "brick and mortar" barrier that keeps water in and germs out. A huge number of genes here being disturbed suggests acne-affected skin is aggressively remodeling or repairing its outer barrier — consistent with the well-known finding that acne-prone skin often has a compromised or leaky skin barrier, not just "clogged pores."
>
> **Bacteria are provoking the immune system.** "Staphylococcus aureus infection" showing up doesn't necessarily mean Staph is the cause of acne (that's usually Cutibacterium acnes), but it reflects that the host's antimicrobial and innate-immune response genes — the ones that respond to bacterial threats in general — are switched on. This tells you lesional skin is actively fighting off or responding to bacteria, i.e., there's a real infection/inflammation component, not just clogged follicles.
>
> **Cells are being broken down and recycled.** "Lysosome" pathway genes relate to the cell's internal "recycling and waste disposal" system, which is also heavily used by immune cells (like macrophages and neutrophils) to digest bacteria and cellular debris. Its enrichment fits with an active inflammatory clean-up operation happening in the lesion.
>
> **Skin cells are responding to stress and changing their turnover.** "Cell cycle" and "p53 signaling" together are consistent with altered skin-cell proliferation, stress responses, and turnover (p53 is the "guardian" gene that checks for DNA damage and decides whether a cell should keep growing, pause, or self-destruct). This may occur during tissue disruption and repair around an inflamed follicle. 
>
> **The seal between skin cells is being disrupted.** "Tight junction" genes control how skin cells physically bind together and control what passes between them. Changes here point to a leakier, less-organized epidermal barrier — again reinforcing the "barrier breakdown" theme.
>
> **Putting it together, in one sentence:** Your data suggests that acne lesions aren't just "clogged pores" — they represent a skin barrier that is breaking down and trying to rebuild itself, while immune cells respond to bacteria and clear away debris, and skin cells ramp up division to repair the damage.
>
> The remaining pathways (PI3K-Akt, efferocytosis, integrin signaling, Hippo, ECM-receptor interaction, complement/coagulation) all support this same story from different angles — cell survival/growth signaling, clearance of dead cells, cell-to-structure attachment, tissue growth control, and inflammation/clotting — the classic molecular fingerprint of a tissue that is inflamed and actively remodeling itself.

### Human review and correction

**Genuine oversimplifications in the AI's response, given what it was asked:**

- **The lysosome explanation is incomplete.** The AI framed lysosome pathway enrichment purely as immune-cell debris clearance. Lysosomes are also central to sebocyte lipid processing directly relevant to acne, where excess sebum production is a core disease driver. This is a real gap, not a scope issue, since sebum biology is squarely within what a general "explain this pathway" prompt should surface.
- **The closing paragraph over-unifies six independent pathways.** Folding PI3K-Akt, efferocytosis, integrin signaling, Hippo signaling, ECM-receptor interaction, and complement/coagulation into one seamless narrative overstates how tightly connected these statistically separate results actually are. This is a generic tendency of AI-generated summaries to favor a satisfying story over precise, pathway-by-pathway caution.

**What the AI got right:** the *Staphylococcus aureus infection* explanation was handled well as it correctly avoided implying *S. aureus* causes acne, correctly identified *Cutibacterium acnes* as the actual associated organism, and correctly reframed the pathway as a general antimicrobial response signature.

**Additions from human domain knowledge (not errors in the AI's response i.e, outside what the prompt asked):**

- **The pseudobulk cell-composition caveat.** This analysis cannot distinguish "immune cells working harder" from "more immune cells present in lesional tissue", a limitation specific to pseudobulk RNA-seq data established during this project's own methodology (see Limitations). A general pathway-interpretation prompt had no way to know about or address this.
- **The KEGG pathway-naming caveat.** Three enriched pathways: "Pertussis," "Mineral absorption," and "Bladder cancer" reflect KEGG's historical naming conventions (gene sets first characterized in those disease contexts) rather than literal relevance to those conditions. This context came from familiarity with KEGG's database structure, not something absent from the AI's reasoning about the biology itself.

### Final corrected interpretation

**The skin barrier is under construction (and struggling).** "Cornified envelope formation" is the single most statistically significant pathway in this analysis, not just one of several strong signals, but the strongest by a clear margin. This pathway builds the tough outer layer of skin cells that forms the skin's protective barrier. Genes here being disturbed is consistent with the well-documented finding that acne-affected skin often has a compromised barrier, alongside not instead of clogged pores.

**Bacteria are provoking a general antimicrobial response but the naming is misleading.** "Staphylococcus aureus infection" appearing here does not mean *S. aureus* causes acne, the bacterium most associated with acne is *Cutibacterium acnes*. This KEGG pathway captures general antibacterial and innate-immune genes that overlap across many bacterial infection as its presence reflects an active antimicrobial immune response in lesional skin, not evidence implicating *S. aureus* specifically.

**Cells are recycling material and this connects to sebum, not just immune clean-up.** Lysosome genes are involved in general cellular waste breakdown, which immune cells use to digest bacteria and debris. But lysosomes are also central to how sebocytes (oil-producing skin cells) process lipids. Given that excess sebum production is one of the core drivers of acne, this pathway's enrichment plausibly reflects altered sebum processing as much as, or more than, immune activity.

**Skin cells are dividing and dying more than usual.** "Cell cycle" and "p53 signaling" together suggest increased skin cell proliferation and turnover, consistent with keratinocyte over-multiplication around an inflamed, blocked follicle.

**The seal between skin cells is being disrupted.** "Tight junction" gene changes point to a less-organized epidermal barrier, reinforcing the barrier-breakdown theme from the top pathway.

**An important caveat this analysis cannot resolve.** This data comes from pseudobulk RNA-seq (counts summed across many individual cells per sample, not measured cell-by-cell). This means the analysis cannot distinguish between two different explanations for the immune-related signal: (1) individual immune cells working harder, producing more of these genes each, versus (2) simply more immune cells being present in lesional tissue than non-lesional tissue. Both would produce the same result in this kind of data.

**On the remaining pathways, and three pathways worth flagging separately.** PI3K-Akt signalling, efferocytosis, integrin signalling, Hippo signalling, ECM-receptor interaction, and complement/coagulation cascades each genuinely reflect a distinct biological process (cell survival signaling, dead-cell clearance, cell-matrix attachment, tissue growth regulation, and clotting/inflammation, respectively) that plausibly co-occurs in inflamed, remodeling tissue but claiming they all "tell the same story" overstates how tightly connected six statistically independent pathways actually are.

Separately, three enriched pathway; "Pertussis," "Mineral absorption," and "Bladder cancer" should not be read literally. These are KEGG's historical naming conventions: gene sets first characterized in the context of those specific diseases, but representing more general underlying biology (cell-cycle or immune-signaling genes, in this case) rather than any actual connection to whooping cough, mineral deficiency, or cancer.

**In one honest sentence:** the data is consistent with acne-lesional skin undergoing barrier breakdown and repair, immune/antimicrobial activity, and increased cell turnover but a pseudobulk analysis on 6 donors cannot distinguish cell-composition effects from true per-cell expression changes, and several pathway names require careful interpretation rather than literal reading.

## Limitations

**1. Pseudobulk rather than true bulk RNA-seq.** This analysis aggregates single-cell data into donor-level pseudobulk samples rather than using a conventional bulk RNA-seq experiment. This avoids pseudo-replication but sacrifices the cell-type-specific resolution available in the original single-cell data.

**2. Cell composition effects.** Because pseudobulk samples combine multiple cell populations, differences in cell-type composition between lesional and non-lesional skin could contribute to observed differential expression for example, apparent upregulation of macrophage-associated genes could reflect a higher proportion of macrophages in lesional tissue rather than increased expression per cell.

**3. Small number of biological replicates.** Only six donors were available. The paired design accounts for donor-level variation, but a larger cohort would improve statistical power and generalisability.

**4. Count rounding.** Aggregated pseudobulk counts were non-integer (reflecting that the source data had already undergone ambient RNA decontamination) and were rounded before DESeq2 analysis, since DESeq2 requires integer input. This is a practical preprocessing step, but it represents a deviation from the original non-integer values (raw sequencing counts).

**5. Heatmap clustering was incomplete.** The top 30 genes shown in the heatmap were selected by statistical confidence (lowest adjusted p-value), not effect size. Small but highly consistent differences can produce very low p-values without necessarily producing a visually dramatic separation between conditions, and individual donor identity can influence clustering alongside the condition effect. As a result, not all donors' samples clustered cleanly by lesional/non-lesional status on the heatmap, even though the full DESeq2 analysis identified a substantial number of statistically significant genes.

**6. Pathway name interpretation.** Some enriched KEGG pathways carry disease-specific names (e.g., "Bladder cancer," "Pertussis") that reflect the context in which the underlying gene sets were first characterized, not literal evidence of those diseases. These pathway labels should be interpreted as describing shared underlying biology (e.g., cell-cycle or immune-signaling genes), not direct disease associations.

**7. Classifier evaluation is high-variance.** The 66.7% LOOCV accuracy is based on only 12 individual test predictions, so it should be read as a proof-of-concept signal that the expression data contains some predictive information, not as a robust, generalizable performance estimate. An initial version of this analysis suffered from data leakage (see "Classifier" section above); this was identified and corrected before reporting the final result.

**8. Genes with zero variance during LOOCV.** During cross-validation, a small number of genes had identical expression values across all 11 training samples in some folds (likely low-expression genes with little variation at this sample size), which scikit-learn correctly excluded from feature scoring rather than producing an error. This is a further reflection of how thin the statistical ground is at n = 12, rather than an issue with the pipeline itself.

## Tools and Technologies

R, Bioconductor, GEOquery, DESeq2, clusterProfiler, STRINGdb, ggplot2, pheatmap, Python, scikit-learn, pandas, NCBI GEO, KEGG, STRING

## Project Outputs

- `volcano_plot.png` - differential expression volcano plot
- `heatmap_top30.png` - heatmap of the top 30 significant genes
- `kegg_dotplot.png` - KEGG pathway enrichment analysis
- `string_network_top100.png` - STRING protein-protein interaction network
- `acne_pseudobulk_DESeq2.R` - full R analysis script, from pseudobulk generation through differential expression, pathway enrichment, and protein interaction analysis
- `acne_classifier.ipynb` - Python notebook containing the leak-free LOOCV classifier pipeline and evaluation

## Repository Structure

```
ai-augmented-acne-transcriptomics-pipeline/
│
├── README.md
│
├── scripts/
│   ├── acne_pseudobulk_DESeq2.R
│   └── acne_classifier.ipynb
│
├── data/
│   ├── classifier_input.csv
│   └── classifier_input_full.csv
│
└── results/
    ├── volcano_plot.png
    ├── heatmap_top30.png
    ├── kegg_dotplot.png
    └── string_network_top100.png
```

Raw GEO data are not included in the repository. The dataset can be obtained from NCBI GEO using accession GSE175817.

## Project Outcome

This project demonstrates a complete transcriptomic analysis workflow using public biological data, extended with a machine learning classification layer and AI-assisted interpretation:

scRNA-seq count data → donor-level pseudobulk → paired differential expression → visualisation → pathway enrichment → protein interaction analysis → machine learning classification → AI-assisted plain-English interpretation (human-reviewed)

The project demonstrates practical experience with R, DESeq2, Bioconductor, GEO data, differential expression analysis, pathway enrichment, protein interaction analysis, Python, scikit-learn, and biological interpretation including reasoned methodological trade-offs (choosing pseudobulk RNA-seq over microarray data), honest reporting of limitations, identifying and correcting a genuine machine learning error (data leakage), and critically reviewing AI-generated scientific content against actual biological knowledge rather than accepting it uncritically.
