import json
from dataclasses import dataclass, asdict
from typing import Dict, Any, List, Optional, Callable

# ==========================================
# 1. ARCHITECTURAL DATA MODELS
# ==========================================

@dataclass(frozen=True)
class PolicyProfile:
    # 1. Ontology (Information Architecture & Content)
    routing_mode: str       # LATERAL_DISCOVERY     | TARGETED_ROUTING
    # 2. Epistemology (Information Design)
    temporal_mode: str      # ATEMPORAL_PERMANENCE  | CHRONOLOGICAL_VELOCITY
    # 3. Kinetics (Interaction Design - IxD)
    functional_intent: str  # PASSIVE_CONSUMPTION   | OPERATIONAL_COMMAND
    # 4. Sensorial (Interface & Visual Design)
    density_mode: str       # CONCEPTUAL_COMPACTION | GRANULAR_PRECISION
    # 5. Teleology (System Orchestration & Macro-Flow)
    macro_flow_mode: str    # ISOLATED_NODE         | SEQUENTIAL_ORCHESTRATION
    # 6. Full-Spectrum Execution Flag
    synthesis_level: str    # STANDARD              | OMNI_PILLAR_SYNTHESIS

@dataclass(frozen=True)
class GlobalBlueprint:
    paradigm_name: str
    ux_taxonomy_pillars: List[str]
    core_utility: str
    implementation_dna: str

@dataclass
class ValidationResult:
    is_valid: bool
    confidence_score: float
    drift_diagnosis: Optional[str] = None
    suggested_remedy: Optional[str] = None

class LLMClientInterface:
    """Interface wrapper for your backend LLM execution layer."""
    def call(self, system_prompt: str, user_prompt: str) -> str:
        raise NotImplementedError("Integrate your active project client here.")

# ==========================================
# 2. THE PARADIGM ENGINE
# ==========================================

class GlobalWebParadigmEngine:
    """
    Blueprint repository mapping open-web design paradigms directly 
    to the 5 Pillars of the MECE UX Taxonomy.
    """
    def __init__(self):
        self._registry: Dict[str, List[GlobalBlueprint]] = {
            "SEMANTIC": [
                GlobalBlueprint(
                    paradigm_name="STRIPE_STYLE_MEGA_FLYOUT",
                    ux_taxonomy_pillars=["Ontology (Information Architecture)", "Sensorial (Visual Design)"],
                    core_utility="Contextual navigation with fluid spatial continuity.",
                    implementation_dna=(
                        "Leverage standard semantic layout wrappers. Use clean, spacious container "
                        "groupings with highly descriptive link subtext to favor LATERAL_DISCOVERY. "
                        "Keep interactions purely exploratory; avoid placing raw data streams inside."
                    )
                ),
                GlobalBlueprint(
                    paradigm_name="APPLE_STYLE_BENTO_GRID",
                    ux_taxonomy_pillars=["Sensorial (Visual Design)", "Epistemology (Information Design)"],
                    core_utility="High-impact macro grouping of disparate value propositions.",
                    implementation_dna=(
                        "Utilize an uneven layout matrix grid. Each block must prioritize a singular macro icon, "
                        "a bold headline, and a short narrative sentence. Maintain absolute ATEMPORAL_PERMANENCE "
                        "by forbidding dynamic metrics, timers, or real-time counters."
                    )
                )
            ],
            "SYNTACTIC": [
                GlobalBlueprint(
                    paradigm_name="LINEAR_STYLE_COMMAND_K_MATRIX",
                    ux_taxonomy_pillars=["Kinetics (Interaction Design)", "Ontology (Information Architecture)"],
                    core_utility="Blazing fast, high-density keyboard-driven operational execution.",
                    implementation_dna=(
                        "Render an ultra-high-density list interface optimized for rapid cognitive scanning. "
                        "Every element must feature clear state indicators, action badges, and localized shortcut layouts. "
                        "Expose clear mutation entry points to fulfill OPERATIONAL_COMMAND."
                    )
                ),
                GlobalBlueprint(
                    paradigm_name="VERCEL_STYLE_DEPLOYMENT_TELEMETRY",
                    ux_taxonomy_pillars=["Epistemology (Information Design)", "Sensorial (Visual Design)"],
                    core_utility="Real-time multi-dimensional infrastructure tracking and triage.",
                    implementation_dna=(
                        "Structure a dense columnar schema layout where records are treated as vectors. "
                        "Incorporate relative delta markers, metrics, or performance trajectories mapping velocity vectors "
                        "to rigidly enforce CHRONOLOGICAL_VELOCITY."
                    )
                ),
                GlobalBlueprint(
                    paradigm_name="SHOPIFY_STYLE_LINEAR_CHECKOUT",
                    ux_taxonomy_pillars=["Teleology (System Orchestration)", "Kinetics (Interaction Design)"],
                    core_utility="High-conversion, multi-state data collection pipeline.",
                    implementation_dna=(
                        "Break complex data collection into discrete, sequential chronological views. "
                        "Enforce strict teleological momentum: hide lateral navigation options (like the main header) "
                        "to prevent the user from breaking the sequence. Validate state at each node before permitting progression."
                    )
                )
            ]
        }

    def fetch_blueprints(self, mode: str) -> List[GlobalBlueprint]:
        return self._registry.get(mode, [])

# ==========================================
# 3. THE STRUCTURED CRITIC & VALIDATOR
# ==========================================

class PolicyValidator:
    """
    Evaluates generated components using heuristic fast-guards and a 
    deep LLM semantic critic equipped with CRUDPA and METRICS synthesis checking.
    """
    def __init__(self, llm_client: LLMClientInterface):
        self.llm = llm_client

    def verify(self, generated_code: str, policy: PolicyProfile, blueprints: List[GlobalBlueprint]) -> ValidationResult:
        code_lower = generated_code.lower()
        
        # Heuristic Guard: Epistemology (Pillar 2)
        if policy.temporal_mode == "CHRONOLOGICAL_VELOCITY":
            temporal_signals = ["delta", "trend", "history", "forecast", "horizon", "trajectory", "30d", "90d"]
            if not any(signal in code_lower for signal in temporal_signals):
                return ValidationResult(
                    is_valid=False, confidence_score=1.0,
                    drift_diagnosis="TEMPORAL OMISSION (Pillar 2): Output renders a static snapshot with no delta trackers.",
                    suggested_remedy="Refactor the data structure to ingest baseline trajectories and relative time-horizon deltas."
                )

        # Heuristic Guard: Kinetics (Pillar 3)
        if policy.functional_intent == "OPERATIONAL_COMMAND":
            control_signals = ["toggle", "action", "handler", "onchange", "onclick", "button", "update", "mutate"]
            if not any(signal in code_lower for signal in control_signals):
                return ValidationResult(
                    is_valid=False, confidence_score=1.0,
                    drift_diagnosis="FUNCTIONAL DRIFT (Pillar 3): Output contains zero transactional mutations.",
                    suggested_remedy="Expose actionable parameters as immediately accessible primary-level controls."
                )

        # Heuristic Guard: Teleology (Pillar 5)
        if policy.macro_flow_mode == "SEQUENTIAL_ORCHESTRATION":
            state_signals = ["step", "next", "prev", "dispatch", "context", "state", "wizard", "payload", "provider"]
            if not any(signal in code_lower for signal in state_signals):
                return ValidationResult(
                    is_valid=False, confidence_score=1.0,
                    drift_diagnosis="ORCHESTRATION FAILURE (Pillar 5): Artifact lacks cross-step state management logic linking UI nodes.",
                    suggested_remedy="Inject a state-retention context, sequential validators, and step-transition handlers."
                )

        return self._run_semantic_critique(generated_code, policy, blueprints)

    def _run_semantic_critique(self, generated_code: str, policy: PolicyProfile, blueprints: List[GlobalBlueprint]) -> ValidationResult:
        system_prompt = (
            "You are an automated structural validator for an engineering harness.\n"
            "Analyze the provided greenfield code artifact against the designated 5-Pillar operational policies. "
            "Output your analysis strictly in valid JSON with keys: 'is_valid', 'diagnosis', 'remedy'."
        )
        
        serialized_blueprints = [asdict(b) for b in blueprints]
        
        user_prompt = f"""
        TARGET 5-PILLAR POLICY CONFIGURATION:
        1. Ontology (Routing): {policy.routing_mode}
        2. Epistemology (Temporal): {policy.temporal_mode}
        3. Kinetics (Function): {policy.functional_intent}
        4. Sensorial (Density): {policy.density_mode}
        5. Teleology (Orchestration): {policy.macro_flow_mode}

        AUTHORIZED RECONSTRUCTION BLUEPRINTS:
        {json.dumps(serialized_blueprints, indent=2)}

        CODE ARTIFACT TO EVALUATE:
        ```
        {generated_code}
        ```
        """

        # Inject Structured Evaluator for Synthesis
        if policy.synthesis_level == "OMNI_PILLAR_SYNTHESIS":
            user_prompt += """
        ====================================================================
        CRITICAL: OMNI-PILLAR SYNTHESIS EVALUATION MANDATE
        ====================================================================
        Because this artifact requires full-spectrum synthesis, you must objectively 
        evaluate the systemic macro-flow using the CRUDPA and METRICS frameworks.

        1. CRUDPA STATE MUTATION CHECK (Kinetics + Teleology):
           To pass validation, the code must support the full lifecycle of its data payload:
           - [C] Create: Does the component support the initialization of new state/payloads?
           - [R] Read: Is the epistemological data clearly mapped, scoped, and visually legible?
           - [U] Update: Are kinetic triggers explicitly wired to mutate the data state?
           - [D] Delete: Are destructive actions present and safely guarded by orchestration logic?
           - [P] Promote: Does the state transition successfully to the next sequential workflow node?
           - [A] Archive: Is historical state, log data, or artifact memory preserved in the layout?

        2. METRICS TELEMETRY EVALUATION (Epistemology + Sensorial):
           - Does the visual layout (Density) successfully expose actionable quantitative metrics?
           - Does the systemic sequence allow for analytical tracking between state transitions?

        If the artifact fails to satisfy the CRUDPA lifecycle or obscures the required METRICS telemetry, 
        you MUST fail the validation (`is_valid: false`) and explicitly diagnose the missing structural logic.
        """
        else:
            user_prompt += """
        Examine if the code drifts from the base 5-Pillar parameters or violates the core structural intent 
        of the global web blueprint.
        """
        
        try:
            response_text = self.llm.call(system_prompt, user_prompt)
            clean_json = response_text.replace("```json", "").replace("```", "").strip()
            data = json.loads(clean_json)
            return ValidationResult(
                is_valid=data.get("is_valid", True),
                confidence_score=0.9,
                drift_diagnosis=data.get("diagnosis"),
                suggested_remedy=data.get("remedy")
            )
        except Exception as e:
            return ValidationResult(
                is_valid=False, confidence_score=0.0,
                drift_diagnosis=f"Validator pipeline crashed: {str(e)}",
                suggested_remedy="Escalate to human review."
            )

# ==========================================
# 4. THE EXECUTION HARNESS
# ==========================================

class ClosedLoopAgentHarness:
    """
    Executes development prompts through 5-Pillar policy vectors,
    manages automated transparent healing, and handles chat escalation.
    """
    def __init__(self, llm_client: LLMClientInterface, validator: PolicyValidator, engine: GlobalWebParadigmEngine):
        self.llm = llm_client
        self.validator = validator
        self.engine = engine

    def execute_harness_loop(self, feature_prompt: str, app_context: dict, max_healing_attempts: int = 3) -> dict:
        interpretation_mode = self._determine_interpretation_mode(app_context)
        policy = self._resolve_policy_profile(interpretation_mode, app_context)
        blueprints = self.engine.fetch_blueprints(interpretation_mode)
        system_directives = self._build_system_directives(policy, blueprints)
        
        feedback_history: List[Dict[str, str]] = []

        for attempt in range(1, max_healing_attempts + 1):
            current_user_prompt = feature_prompt
            if feedback_history:
                latest_feedback = feedback_history[-1]
                current_user_prompt += (
                    f"\n\n⚠️ MECE PILLAR DEVIATION MANDATE (ATTEMPT {attempt}):\n"
                    f"DIAGNOSIS: {latest_feedback['diagnosis']}\n"
                    f"REQUIRED REFACTORING: {latest_feedback['remedy']}\n"
                    f"Re-analyze the architectural layout parameters and rebuild the component to reconcile this variance."
                )

            generated_artifact = self.llm.call(system_directives, current_user_prompt)
            validation = self.validator.verify(generated_artifact, policy, blueprints)
            
            if validation.is_valid:
                # Transparent Healing Intercept
                if attempt > 1:
                    self._report_auto_repair_to_chat(policy, feedback_history)

                return {
                    "status": "STABLE_WITH_REPAIRS" if attempt > 1 else "STABLE",
                    "mode_executed": asdict(policy),
                    "artifact": generated_artifact,
                    "healing_cycles": attempt - 1
                }
            
            drift_entry = {
                "attempt": str(attempt),
                "diagnosis": validation.drift_diagnosis or "Unknown UX Pillar breach.",
                "remedy": validation.suggested_remedy or "Align code structure with authorized 5-pillar parameters."
            }
            feedback_history.append(drift_entry)

        return self._escalate_to_chat_modality(policy, generated_artifact, feedback_history)

    def _determine_interpretation_mode(self, context: dict) -> str:
        auth_state = context.get("auth_state", "UNAUTHENTICATED")
        current_view = context.get("current_view", "MARKETING_PAGE")
        if auth_state == "UNAUTHENTICATED" or current_view == "MARKETING_PAGE":
            return "SEMANTIC"
        return "SYNTACTIC"

    def _resolve_policy_profile(self, mode: str, context: dict) -> PolicyProfile:
        is_complex_artifact = context.get("is_complex_artifact", False)
        
        if mode == "SEMANTIC":
            return PolicyProfile(
                routing_mode="LATERAL_DISCOVERY",
                temporal_mode="ATEMPORAL_PERMANENCE",
                
                # Upgrade 1: Allow kinetic control even on unauthenticated screens
                functional_intent="OPERATIONAL_COMMAND" if is_complex_artifact else "PASSIVE_CONSUMPTION",
                
                density_mode="CONCEPTUAL_COMPACTION",
                
                # Upgrade 2: Default to sequential transitions to allow fluid exploration loops
                macro_flow_mode="SEQUENTIAL_ORCHESTRATION", 
                
                # Upgrade 3: Force full-spectrum synthesis so the visuals respond to click states
                synthesis_level="OMNI_PILLAR_SYNTHESIS"
            )
        else:
            return PolicyProfile(
                routing_mode="TARGETED_ROUTING",
                temporal_mode="CHRONOLOGICAL_VELOCITY",
                functional_intent="OPERATIONAL_COMMAND",
                density_mode="GRANULAR_PRECISION",
                macro_flow_mode="SEQUENTIAL_ORCHESTRATION" if is_complex_artifact else "ISOLATED_NODE",
                synthesis_level="OMNI_PILLAR_SYNTHESIS" if is_complex_artifact else "STANDARD"
            )

    def _build_system_directives(self, policy: PolicyProfile, blueprints: List[GlobalBlueprint]) -> str:
        serialized_blueprints = [asdict(b) for b in blueprints]
        
        directives = f"""
        You are a highly contextual generation engine operating inside a strict structural harness.
        You are building a greenfield codebase. Your output must conform to these 5 UX Taxonomy Pillars:

        1. ONTOLOGY (Routing): [{policy.routing_mode}]
        2. EPISTEMOLOGY (Information Design): [{policy.temporal_mode}]
        3. KINETICS (Interaction Design): [{policy.functional_intent}]
        4. SENSORIAL (Visual Design & Density): [{policy.density_mode}]
        5. TELEOLOGY (Macro-Flow): [{policy.macro_flow_mode}]

        AUTHORIZED GLOBAL OPEN-WEB BLUEPRINTS:
        {json.dumps(serialized_blueprints, indent=2)}
        """

        if policy.synthesis_level == "OMNI_PILLAR_SYNTHESIS":
            directives += """
        \nOMNI-PILLAR SYNTHESIS MANDATE:
        You are not building a static screen; you are engineering a multi-dimensional artifact. 
        You must synthesize all 5 UX Pillars into a single, cohesive component architecture.
        The kinetic interactions MUST drive the epistemological data changes within the sensorial layout.
        Ensure robust state-management binds sibling elements together orchestrating a seamless macro-flow.
        """
            
        return directives

    def _report_auto_repair_to_chat(self, policy: PolicyProfile, history: List[dict]):
        latest_repair = history[-1]
        receipt_block = f"""
================================================================================
🛠️ AGENT HARNESS NOTIFICATION: TRANSPARENT HEALING EXECUTED
================================================================================
The agent generated the framework but required automated intervention to 
align with the 5-Pillar MECE constraints.

[DRIFT DETECTED]: {latest_repair['diagnosis']}
[REPAIR APPLIED]: {latest_repair['remedy']}

System velocity maintained. Please review the repaired artifact.
================================================================================
"""
        print(receipt_block)

    def _escalate_to_chat_modality(self, policy: PolicyProfile, artifact: str, history: List[dict]) -> dict:
        escalation_block = f"""
================================================================================
🚨 AGENT HARNESS ESCALATION: 5-PILLAR ALIGNMENT BREACH
================================================================================
The automated self-healing pipeline has exhausted its retry budget. The generation 
agent is trapped in an architectural loop, consistently drifting from compliance.

TARGET 5-PILLAR PROFILE:
{json.dumps(asdict(policy), indent=2)}

DRIFT ENFORCEMENT SUMMARY LOG:
{json.dumps(history, indent=2)}

NARROW RESOLUTION QUESTION FOR THE CHAT THREAD:
The agent cannot satisfy the current Pillar requirements. Please reply in the chat:
1. "Override policy: Force downshift to SEMANTIC variants."
2. "Adjust intent: Provide specific layout constraints."
3. Provide direct clarification on how your data schema resolves the blocked Pillar.
================================================================================
"""
        print(escalation_block)
        return {
            "status": "ESCALATED_TO_CHAT",
            "active_policy": asdict(policy),
            "last_unstable_artifact": artifact
        }
