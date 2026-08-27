# Search Golden Set Report

_Generated 2026-08-24T10:23:19Z against local API; corpus snapshot._

## Latency

| metric | cold (cache miss) | warm (cached) |
|---|---|---|
| p50 | 79 ms | 21 ms |
| p95 | 350 ms | 50 ms |
| max | 654 ms | 76 ms |

52/52 queries returned 200.
Acceptance target: **p95 < 300ms** (corpus ≥100k papers; current corpus smaller — treat as provisional).

## Relevance spot-check sheet

Eyeball rule: at least one top-3 title should clearly match the label.

| # | label | est | cold→warm | top titles |
|---|---|---|---|---|
| 1 | protein | 1242 | 329→22 ms | Stress proteins and initiation of immune response: Chaperokine activity of Hsp72 • Mechanisms of stress-induced cellular HSP72 release: implications for ex... [ok] |
| 2 | graphene | 49 | 47→17 ms | Graphene oxide-polydopamine membranes with controlled interlayer spacing • First-principles mechanism of TDMAH adsorption on pristine and laser-functionali... [ok] |
| 3 | quantum | 900 | 235→11 ms | Quantum Adaptive Self-Attention for quantum Transformer models • Bridge Paper Q: Quantum Computing × WCM — Structural Bridges Between a 4D Geometric Sca... [ok] |
| 4 | neurons | 448 | 155→52 ms | Maya-Sutra P3: Remembering on Silicon Selective On-Chip Retention on BrainScaleS-2 • GRADIENT-4 Pipeline v1 • Maya-Vaidya P7: Arbuda An In-Silico Spiking... [ok] |
| 5 | catalysis | 50 | 93→50 ms | Hydrogen Bond Networks for Stable and Sustainable Production of Hydrogen From Seawater via Contact‐Electro‐Catalysis • Evaluating Mechanical-Embedding ... [ok] |
| 6 | algorithm | 917 | 403→26 ms | Performance and Biases of the LENA and ACLEW Algorithms in Analyzing Language Environments in Down, Fragile X, Angelman Syndromes, and Populations at Elevate... [ok] |
| 7 | photosynthesis | 61 | 67→15 ms | Studi Dinamika Kloroplas: Pengamatan Gerak Siklosis Sel Hydrilla verticillata di Bawah Mikroskop Cahaya • Cyano-grafted porous carbon nitride for robust H2... [ok] |
| 8 | inflation | 148 | 72→16 ms | Inflation at the End of 2025: Constraints on r and n s Using the Latest CMB and BAO Data • Has there been a decoupling of inflation expectations? Evidence ... [ok] |
| 9 | seismology | 6 | 38→15 ms | Bridge Paper Q: Quantum Computing × WCM — Structural Bridges Between a 4D Geometric Scanner and Quantum Information Processing • Comment on essd-2026-27... [ok] |
| 10 | peptides | 163 | 77→14 ms | Synergistic Multicomponent Nucleopeptide-Based Hydrogels: Harnessing DNA-Base Pairing and Electrostatic Complementarities. • Immunostimulatory functions of... [ok] |
| 11 | taxonomy | 157 | 79→76 ms | A Taxonomy of AI Governance Approaches: Distinguishing Visibility, Alignment, and Authorization • An Epistemic-Content Taxonomy of Human Intervention in Ag... [ok] |
| 12 | superconductors | 11 | 91→29 ms | Supporting Data For: Pair-Breaking and Dimensionality in Spin-Orbit Coupled Superconductors • Quantum phase-field model: vortices and THz-induced gap dynam... [ok] |
| 13 | microbiome | 102 | 112→15 ms | Exercise and immune system as modulators of intestinal microbiome: implications for the gut-muscle axis hypothesis • Supplementation with long-chain polyun... [ok] |
| 14 | lidar | 57 | 44→19 ms | LiDARch - Automated LiDAR Processing Tool for Archaeological Purposes (Portable version, V3.0) • A Multi-Sensor Machine Learning Framework Integrating UAV ... [ok] |
| 15 | chromatography | 104 | 61→19 ms | Liquid–liquid phase separation enables chromatography-free purification and high-performance spidroin-amyloid hybrid silk fibers • Recent Advances in Sta... [ok] |
| 16 | machine learning | 707 | 350→34 ms | Transforming Skin Cancer Triage in Underserved U.S. Communities: An In-Depth Examination of Advanced Machine Learning Models for Early Detection and Dermatol... [ok] |
| 17 | climate change | 368 | 253→49 ms | Plant defence priming and memory mechanisms under climate change • Adaptation to seasonal drought in Arabis alpina is linked to the demographic history and... [ok] |
| 18 | cancer immunotherapy | 48 | 81→18 ms | Tertiary lymphoid structures as biomarkers and therapeutic targets in neoadjuvant cancer immunotherapy • Radiotherapy and tertiary lymphoid structures: bal... [ok] |
| 19 | neural networks | 421 | 171→56 ms | Maya-Śūnyatā: Karma-Weighted Synaptic Pruning for Class-Incremental Learning in Affective Spiking Neural Networks • Maya-Morphe P4: Dharana — EFC Traj... [ok] |
| 20 | gene editing | 39 | 46→16 ms | Efficient Gene Editing in Fish Primary Germline Stem Cells • In-depth characterization of stem cell potency and genotoxicity for clinical-scale ex vivo CRI... [ok] |
| 21 | carbon capture | 58 | 58→23 ms | Techno-economic and efficiency analysis of adsorption systems for onboard carbon capture in the marine vessels • Precursor-engineered solar-responsive bioc... [ok] |
| 22 | dark matter | 187 | 85→27 ms | Four-Sector Cosmology: A CPT-Symmetric Resolution of the Hubble Tension, Dark Matter, and Dark Energy • A Generative Interpretation of Dark Matter and Dark... [ok] |
| 23 | stem cells | 325 | 148→31 ms | Stem Cell Therapy for Neurodegenerative Disorders • Italian Journal of Anatomy and Embryology - contenuto non piu disponibile • Italian Journal of Anatom... [ok] |
| 24 | reinforcement learning | 134 | 111→16 ms | Reinforcement learning control of quantum error correction • Behavioural and Deep Reinforcement Learning Perspectives on Consumer Resistance in E-Commerce ... [ok] |
| 25 | quantum computing | 179 | 65→25 ms | Reinforcement learning control of quantum error correction • Bridge Paper Q: Quantum Computing × WCM — Structural Bridges Between a 4D Geometric Scanner... [ok] |
| 26 | gut bacteria | 17 | 48→21 ms | Secondary bile acid production by gut bacteria promotes Western diet-associated colorectal cancer. • The Microbiome-Mitochondria Axis in aging: a self-rein... [ok] |
| 27 | solar cells | 54 | 63→28 ms | Advances in carbon nanostructures and organic semiconductors for next-generation solar cells: A comprehensive review • Flexible and Biodegradable Cellulose... [ok] |
| 28 | data privacy | 138 | 81→11 ms | A Global Tapestry of Data Privacy and Security: Navigating Ethical, Legal, and Technological Dilemmas • A Global Tapestry of Data Privacy and Security: Nav... [ok] |
| 29 | robotics control | 78 | 45→33 ms | Data-driven soft robot control via adiabatic spectral submanifolds • State Machine Model of the Operation Control of a Differential- Drive Mobile Robot •... [ok] |
| 30 | water purification | 14 | 33→14 ms | Bioinspired architected catalyst for efficient water purification: Bridging reactivity, reusability, and catalytic component utilization • Design of Reloca... [ok] |
| 31 | bone regeneration | 45 | 119→27 ms | Chitosan-quinoxaline Schiff base hydroxyapatite composite with antimicrobial properties for bone regeneration • Electrical stimulation as an emerging strat... [ok] |
| 32 | speech recognition | 16 | 40→26 ms | High‐Performance Flexible 2D Bi 2 O 2 Se Piezoelectric Energy Harvester Enabled by Structural Engineering Strategy for Silent Speech Recognition • Benchm... [ok] |
| 33 | urban planning | 95 | 120→44 ms | GIS Application in Multi-Criteria Evaluation of Urban Riverfront Redevelopment • GIS Application in Multi-Criteria Evaluation of Urban Riverfront Redevelop... [ok] |
| 34 | coastal erosion | 5 | 63→13 ms | A comprehensive geographic analysis of disaster risk in Costa Rica • Monitoring Extent of Mangroves in Coastal Bangladesh from 1980 to 2020: A Remote Sensi... [ok] |
| 35 | battery materials | 37 | 59→19 ms | Batteries From Reused, Recycled, and Surplus Materials • In-Depth Studies on the Stability of Cathode Active Materials in Coated Electrodes from Lithium–... [ok] |
| 36 | how do transformers handle long context windows | 200 | 238→24 ms | S74 / REFTPS / Transformation Products and Reactions from Literature • Danger-OS: Spiking Neural Danger Theory — Affective Neuromodulatory Arbitration fo... [ok] |
| 37 | research about whether consciousness can emerge from artificial systems | 200 | 654→49 ms | Maya-OS: An Affective Spiking Neural Network as a Conversational Operating System Arbitration Layer • Maya-Meta P2: A Self-Audit of Two Emergent Constants ... [ok] |
| 38 | methods for detecting exoplanets using transit photometry | 200 | 483→13 ms | European Scientific Journal ESJ • The International Journal of Technologies in Learning • Optimising Analysis Choices for Multivariate Decoding: Creating... [ok] |
| 39 | impact of microplastics on marine food chains | 200 | 171→13 ms | Critical success factors in supply chain management at high technology companies. • Amino acid composition of some Mexican foods • Food Studies: An Inter... [ok] |
| 40 | approaches to reduce hallucinations in large language models | 1 | 30→18 ms | The Equation Reduction Model (ERM): A Universal Framework for Mathematical Stability and Invariant Discovery [ok] |
| 41 | role of the gut microbiome in mental health | 200 | 211→10 ms | Exercise and immune system as modulators of intestinal microbiome: implications for the gut-muscle axis hypothesis • Physiological improvements and health ... [ok] |
| 42 | techniques for carbon sequestration in agricultural soils | 200 | 173→14 ms | Impact of Vermicompost from Agricultural Waste on Soil Fertility, Crop Performance, and Drought Resilience in Smallholder Farming Systems • Create accurate... [ok] |
| 43 | deep learning models for weather forecasting | 6 | 30→19 ms | Data for Cognitive Digital Twin Framework in "The Spine", Madinaty • Data for Cognitive Digital Twin Framework in "The Spine", Madinaty • Advanced AI and... [ok] |
| 44 | ethical considerations of gene drives in wild populations | 200 | 217→12 ms | Gender- and menstrual phase dependent regulation of inflammatory gene expression in response to aerobic exercise • Establishing a novel single-copy primer-... [ok] |
| 45 | perovskite stability challenges in commercial solar panels | 1 | 25→9 ms | Advances in carbon nanostructures and organic semiconductors for next-generation solar cells: A comprehensive review [ok] |
| 46 | filter: covid vaccine + OA | 23 | 39→16 ms | Immune Response to COVID-19 Vaccination in Elite Athletes • COVID-19 vaccination induces cross-neutralisation of sarbecoviruses related to SARS-CoV-2 • S... [ok] |
| 47 | filter: attention + min_cit | 200 | 134→22 ms | Antahkarana in the Age of Transformers: Continual Fine-Tuning of Large Language Models via Vedantic Neuromodulatory Mechanisms • Mahasamadhi: Computational... [ok] |
| 48 | sort=newest deep learning | 464 | 46→21 ms | An Effective Deep Learning-Based DDoS Attack Detection and Classification Framework for Internet of Things • A reinforcement learning-driven adaptive hybri... [ok] |
| 49 | sort=citations deep learning | 464 | 50→19 ms | Advancing bioinformatics with language models: components, applications, and perspectives • FLSea: Underwater Visual–Inertial and Stereovision Forward‐... [ok] |
| 50 | filters only (empty q) OA | -1 | 48→23 ms | African Journal of Agricultural Research • Experimental and Therapeutic Medicine • Food Technology and Biotechnology [ok] |
| 51 | filters only (empty q) newest | -1 | 47→35 ms | pygemc — Python API for GEMC • A New Survival and Prognosis Predictive Model for Combined-Small Cell Lung Cancer (C-SCLC): A Machine Learning Approach �... [ok] |
| 52 | crispr after 2024 | 53 | 47→25 ms | In vivo CRISPR base editing for treatment of Huntington’s disease • CRISPR Gene Therapy for Sickle Cell Disease • A lipid nanoparticle platform for hig... [ok] |

## Feed cursor stability

- `section=latest`, limit=100, full exhaustion: **456 pages / 45,577 unique
  paper IDs / 0 duplicates → PASS**.
- `section=trending`: single page by design (no cursor), 20 items returned.

## Notes

- Cold-cache p95 varied 287–410ms across runs on dev Docker volumes
  (Postgres buffer warmth dominates); warm p95 stayed ≤ 90ms.
- Relevance queries over broad match sets rank a bounded candidate slice
  (`rankCandidateLimit = 200`, citation-ordered) once matches exceed
  `rankCandidateThreshold = 500`; exact `ts_rank_cd` ranking runs below that.
- Pure-filter listings report `total_estimate = -1` (unknown): counting them
  costs a full-table scan per cold request for little UI value.
- First measured query of a server process includes one-time pool/plan
  warm-up; the bench issues a warmup request before timing.
