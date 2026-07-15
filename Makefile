SKILL ?= code-review-back
SKILL_NAME ?= $(SKILL)
SKILL_ROOT ?= skills
SKILL_DIR ?= $(SKILL_ROOT)/$(SKILL)
CASES_DIR ?= evals/cases
RESULTS_DIR ?= evals/results
RUNNER_DIR ?= evals/runner
CASES ?= $(notdir $(wildcard $(CASES_DIR)/*))

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
	@$(RUNNER_DIR)/run-review.sh $@
	@$(RUNNER_DIR)/extract-trace.sh $@
	@$(RUNNER_DIR)/validate-review.sh $@
	@$(RUNNER_DIR)/run-judge.sh $@

gate:
	@$(RUNNER_DIR)/gate.sh $(CASES)

context:
	@$(RUNNER_DIR)/gate.sh --context-only $(CASES)

case:
	@test -n "$(CASE)" || { echo "usage: make case CASE=<case-id>"; exit 2; }
	@$(RUNNER_DIR)/lint-rules.sh
	@$(RUNNER_DIR)/run-review.sh $(CASE)
	@$(RUNNER_DIR)/extract-trace.sh $(CASE)
	@$(RUNNER_DIR)/validate-review.sh $(CASE)
	@$(RUNNER_DIR)/run-judge.sh $(CASE)
	@$(RUNNER_DIR)/gate.sh $(CASE)

clean:
	@find $(RESULTS_DIR) -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +
	@touch $(RESULTS_DIR)/FINDINGS.md
