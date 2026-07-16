SKILL ?= code-review-back
SKILL_NAME ?= $(SKILL)
SKILL_ROOT ?= skills
SKILL_DIR ?= $(SKILL_ROOT)/$(SKILL)
CASES_DIR ?= evals/cases
RESULTS_DIR ?= evals/results
RUNNER_DIR ?= evals/runner
CASES ?= $(notdir $(wildcard $(CASES_DIR)/*))
# Nombre d'iterations par cas. 1 par defaut: le modele coute, et un run unique
# suffit pour un diagnostic. Au-dela, le gate rapporte un ratio k/N au lieu d'un
# PASS/FAIL, ce qui rend la variance du modele visible.
RUNS ?= 1
# Modele epingle. Sans lui, le CLI route seul et deux runs peuvent mesurer deux
# modeles differents: la mesure n'est plus comparable. Requiert un plan Copilot
# Pro ou superieur (la selection manuelle est retiree des plans Free/Student).
# Mettre MODEL= (vide) pour laisser le routage automatique.
# La liste des noms valides n'est pas publiee: la lire avec /model en interactif.
MODEL ?= claude-haiku-4.5

.PHONY: eval all setup lint run gate context case clean $(CASES)

eval: setup run gate

all: eval

setup:
	@mkdir -p $(RESULTS_DIR)
	@command -v copilot >/dev/null || { echo "copilot CLI introuvable"; exit 1; }
	@echo "copilot path: $$(command -v copilot)"
	@copilot --version 2>/dev/null || true
	@copilot --help > $(RESULTS_DIR)/copilot-help.txt 2>&1 || true
	@printf '%s\n' 'OBSERVED: copilot -p --help is parsed as a prompt, not as help. See copilot --help for -p options.' > $(RESULTS_DIR)/copilot-p-help.txt
	@copilot skill list --json > $(RESULTS_DIR)/skill-list.before.json 2>&1 || true
	@copilot skill add $(SKILL_ROOT) > $(RESULTS_DIR)/skill-add.log 2>&1 || true
	@copilot skill list --json > $(RESULTS_DIR)/skill-list.after.json 2>&1 || true
	@printf '%s\n' "$(CASES)" > $(RESULTS_DIR)/cases.list
	@echo "Help capture: $(RESULTS_DIR)/copilot-help.txt, $(RESULTS_DIR)/copilot-p-help.txt"

lint:
	@$(RUNNER_DIR)/lint-rules.sh

run: lint $(CASES)

$(CASES):
	@RUNS=$(RUNS) MODEL="$(MODEL)" $(RUNNER_DIR)/run-case.sh $@

gate:
	@MODEL="$(MODEL)" $(RUNNER_DIR)/gate.sh $(CASES)

context:
	@MODEL="$(MODEL)" $(RUNNER_DIR)/gate.sh --context-only $(CASES)

case:
	@test -n "$(CASE)" || { echo "usage: make case CASE=<case-id>"; exit 2; }
	@$(RUNNER_DIR)/lint-rules.sh
	@RUNS=$(RUNS) MODEL="$(MODEL)" $(RUNNER_DIR)/run-case.sh $(CASE)
	@MODEL="$(MODEL)" $(RUNNER_DIR)/gate.sh $(CASE)

clean:
	@find $(RESULTS_DIR) -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +
	@touch $(RESULTS_DIR)/FINDINGS.md
