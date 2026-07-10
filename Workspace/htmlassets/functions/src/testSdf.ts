import {
  sanitizePrompt,
  forbiddenJsToken,
  normalizeOversizedNumericLiterals,
  fallbackSdf,
  CONTRACT_VERSION
} from "./sdfUtils.js";

// A beautiful, color-coded, zero-dependency test runner
let passCount = 0;
let failCount = 0;

function assert(condition: boolean, message: string) {
  if (condition) {
    console.log(`\x1b[32m✔ PASS:\x1b[0m ${message}`);
    passCount++;
  } else {
    console.error(`\x1b[31m✘ FAIL:\x1b[0m ${message}`);
    failCount++;
  }
}

function runTestSuite() {
  console.log("\x1b[36m==================================================\x1b[0m");
  console.log("\x1b[36m    SDF UTILS - AUTOMATED INTEGRITY TEST SUITE    \x1b[0m");
  console.log("\x1b[36m==================================================\x1b[0m\n");

  // ----------------------------------------------------
  // 1. SANITIZE PROMPT TESTS
  // ----------------------------------------------------
  console.log("\x1b[35m[1] Testing Prompt Sanitization...\x1b[0m");
  
  assert(sanitizePrompt("  umbrella  ") === "umbrella", "Should trim surrounding whitespace");
  assert(sanitizePrompt(123 as any) === "", "Should return empty string for non-string types");
  assert(sanitizePrompt(null as any) === "", "Should return empty string for null");
  
  const longPrompt = "a".repeat(200);
  assert(sanitizePrompt(longPrompt).length === 160, "Should truncate prompts to exactly 160 characters");
  assert(sanitizePrompt(longPrompt) === "a".repeat(160), "Should match expected truncated text");

  console.log("");

  // ----------------------------------------------------
  // 2. FORBIDDEN JS TOKEN TESTS
  // ----------------------------------------------------
  console.log("\x1b[35m[2] Testing JS Safety & Sandbox Filters...\x1b[0m");

  const safeSdf = `function sdf(px, py, pz) {
    const r = 0.5;
    return sdSphere(px, py, pz, r);
  }`;
  assert(forbiddenJsToken(safeSdf) === null, "Should allow safe, standard SDF implementations");

  assert(forbiddenJsToken("const d = new Date();") === "Date", "Should flag forbidden 'Date' token");
  assert(forbiddenJsToken("const r = Math.random();") === "Math.random", "Should flag forbidden 'Math.random' token");
  assert(forbiddenJsToken("eval('1+1');") === "eval", "Should flag forbidden 'eval' token");
  assert(forbiddenJsToken("const f = new Function('a', 'return a');") === "Function", "Should flag forbidden 'Function' constructor");
  assert(forbiddenJsToken("function sdf() {}") === null, "Should NOT flag standard 'function sdf' declarations (case-sensitivity check)");
  assert(forbiddenJsToken("import { something } from 'somewhere';") === "import", "Should flag forbidden 'import' keyword");
  assert(forbiddenJsToken("fetch('https://api.com')") === "fetch", "Should flag forbidden 'fetch' call");
  assert(forbiddenJsToken("window.location") === "window", "Should flag forbidden 'window' context access");
  assert(forbiddenJsToken("document.cookie") === "document", "Should flag forbidden 'document' object access");
  assert(forbiddenJsToken("localStorage.setItem('a', '1')") === "localStorage", "Should flag forbidden 'localStorage'");
  assert(forbiddenJsToken("sessionStorage.getItem('b')") === "sessionStorage", "Should flag forbidden 'sessionStorage'");

  console.log("");

  // ----------------------------------------------------
  // 3. OVERSIZED NUMERIC LITERALS SCALE TESTS
  // ----------------------------------------------------
  console.log("\x1b[35m[3] Testing Numeric Literal Coordinate Scaling (Unit Cube lockdown)...\x1b[0m");

  const testScale1 = "const size = 2.0;";
  const res1 = normalizeOversizedNumericLiterals(testScale1);
  assert(res1.js === "const size = 1;", "Should scale 2.0 down to 1 (2.0 * 0.5)");
  assert(res1.scaledCount === 1, "Should count 1 scaling operation");

  const testScale2 = "sdBox(px, py, pz, 0.5, 4.0, 0.8)";
  const res2 = normalizeOversizedNumericLiterals(testScale2);
  assert(res2.js === "sdBox(px, py, pz, 0.5, 1, 0.8)", "Should scale 4.0 down to 1 (4.0 -> 2.0 -> 1.0) and keep others intact");
  assert(res2.scaledCount === 1, "Should count 1 scaling operation for composite arguments");

  const testScale3 = "const d = -3.2;";
  const res3 = normalizeOversizedNumericLiterals(testScale3);
  assert(res3.js === "const d = -0.8;", "Should scale negative value -3.2 to -0.8 (-3.2 -> -1.6 -> -0.8)");

  const testScale4 = "const normal = 0.75;";
  const res4 = normalizeOversizedNumericLiterals(testScale4);
  assert(res4.js === "const normal = 0.75;", "Should NOT modify values already within standard bounds (-1.0 to 1.0)");
  assert(res4.scaledCount === 0, "Should count 0 scaling operations for normalized code");

  console.log("");

  // ----------------------------------------------------
  // 4. FALLBACK SDF GENERATION TESTS
  // ----------------------------------------------------
  console.log("\x1b[35m[4] Testing Fallback Strategy Contracts...\x1b[0m");

  const fallbackGeneric = fallbackSdf("unicorn", "test-reason");
  assert(fallbackGeneric.is_fallback === true, "Fallback response should have is_fallback set to true");
  assert(fallbackGeneric.contract_version === CONTRACT_VERSION, "Should match system contract version");
  assert(fallbackGeneric.fallback_reason === "test-reason", "Should preserve provided reason in contract");
  assert(fallbackGeneric.kind === "unicorn", "Should map first word of prompt to 'kind'");
  assert(fallbackGeneric.sdf_javascript.includes("function sdf"), "Should generate code containing 'function sdf'");
  assert(fallbackGeneric.sdf_javascript.includes("sdBox"), "Should generate valid primitive logic");

  const fallbackPhone = fallbackSdf("my blue smartPhone object", "no-connection");
  assert(fallbackPhone.kind === "my", "Should extract 'my' as first word");
  assert(fallbackPhone.sdf_javascript.includes("sdBox") && fallbackPhone.sdf_javascript.includes("Math.max"), "Should return phone geometric representation");

  const fallbackMountain = fallbackSdf("mount Everest", "timeout");
  assert(fallbackMountain.sdf_javascript.includes("smin") && fallbackMountain.sdf_javascript.includes("sdCapsule"), "Should return organic mountain ridge representation");

  console.log("");

  // ----------------------------------------------------
  // FINAL EVALUATION REPORT
  // ----------------------------------------------------
  console.log("\x1b[36m==================================================\x1b[0m");
  console.log("             TEST EXECUTION SUMMARY               ");
  console.log("\x1b[36m==================================================\x1b[0m");
  console.log(`  \x1b[32mPassed:\x1b[0m  ${passCount}`);
  console.log(`  \x1b[31mFailed:\x1b[0m  ${failCount}`);
  console.log("\x1b[36m==================================================\x1b[0m\n");

  if (failCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runTestSuite();
