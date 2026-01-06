// @ts-check

(() => {
  // ---- Data (your onboarding steps) ----
  const STEPS = [
    {
      id: "gender",
      type: "question",
      title: "What's your biological sex?",
      description: "This helps us calculate your metabolism accurately.",
      input: { type: "gender_select", options: ["Male", "Female"] },
      next: "height_weight",
    },
    {
      id: "height_weight",
      type: "form",
      title: "Height & weight",
      description: "This will be used to calibrate your plan.",
      fields: [
        { id: "height", label: "Height", required: true, input: { type: "number", placeholder: "170", unitOptions: ["cm", "ft"], defaultUnit: "cm" } },
        { id: "weight", label: "Weight", required: true, input: { type: "number", placeholder: "70", unitOptions: ["kg", "lb"], defaultUnit: "kg" } },
      ],
      next: "birthdate",
    },
    {
      id: "birthdate",
      type: "form",
      title: "When were you born?",
      description: "Your age affects your daily calorie needs.",
      fields: [{ id: "birthdate", label: "Birthdate", required: true, input: { type: "date" } }],
      next: "activity_level",
    },
    {
      id: "activity_level",
      type: "question",
      title: "How active are you?",
      description: "Be honest — this significantly affects your calorie target.",
      input: {
        type: "single_select",
        options: [
          { value: "sedentary", label: "Sedentary", sub: "Little to no exercise, desk job" },
          { value: "lightly_active", label: "Lightly Active", sub: "Light exercise 1-3 days/week" },
          { value: "moderately_active", label: "Moderately Active", sub: "Moderate exercise 3-5 days/week" },
          { value: "very_active", label: "Very Active", sub: "Hard exercise 6-7 days/week" },
          { value: "extra_active", label: "Extra Active", sub: "Very hard exercise, physical job" },
        ],
      },
      next: "goal",
    },
    {
      id: "goal",
      type: "question",
      title: "What is your goal?",
      description: "This helps us generate a plan for your calorie intake.",
      input: {
        type: "single_select",
        options: [
          { value: "lose_weight", label: "Lose weight", sub: "Reduce calories gradually" },
          { value: "maintain", label: "Maintain", sub: "Keep a steady intake" },
          { value: "gain_weight", label: "Gain weight", sub: "Support lean gain" },
        ],
      },
      next: "desired_weight",
    },
    {
      id: "desired_weight",
      type: "question",
      title: "What is your desired weight?",
      input: { type: "slider", min: 40, max: 200, step: 0.5, unit: "kg" },
      next: "goal_speed",
    },
    {
      id: "goal_speed",
      type: "question",
      title: "How fast do you want to reach your goal?",
      description: "Weight change per week. Slower is healthier and more sustainable.",
      input: { type: "slider", min: 0.1, max: 1.0, step: 0.1, unit: "kg/week", default: 0.5 },
      next: "coach",
    },
    {
      id: "coach",
      type: "question",
      title: "Do you work with a coach or nutritionist?",
      input: {
        type: "single_select",
        options: [
          { value: "yes", label: "Yes", sub: "We'll align with your guidance" },
          { value: "no", label: "No", sub: "We'll guide you step-by-step" },
        ],
      },
      next: "notifications",
    },
    {
      id: "notifications",
      type: "info",
      title: "Stay on track",
      description: "You can enable notifications later in settings to get reminders for meals and weight tracking.",
      next: "referral",
    },
    {
      id: "referral",
      type: "question",
      title: "Enter referral code (optional)",
      description: "You can skip this step.",
      optional: true,
      input: { type: "text", placeholder: "Referral code" },
      next: "generating",
    },
    {
      id: "generating",
      type: "goals_generation",
      title: "Generating your plan",
      next: null,
    },
  ];

  // ---- State ----
  const byId = new Map(STEPS.map((s) => [s.id, s]));
  const order = STEPS.map((s) => s.id);
  const state = {
    currentId: STEPS[0].id,
    stack: [],
    answers: {},
    generatedGoals: null,
  };

  // ---- Native bridge helper (iOS WKWebView) ----
  function postToNative(type, payload) {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onboarding) {
        window.webkit.messageHandlers.onboarding.postMessage({ type, payload });
        return true;
      }
    } catch (_) {}
    window.dispatchEvent(new CustomEvent("onboarding", { detail: { type, payload } }));
    return false;
  }

  // ---- Utilities ----
  function clamp(n, min, max) { return Math.min(max, Math.max(min, n)); }
  function fmtNumber(n, step) {
    const decimals = (String(step).split(".")[1] || "").length;
    return Number(n).toFixed(decimals);
  }

  function toCm(height, unit) {
    const v = Number(height);
    if (!Number.isFinite(v)) return null;
    return unit === "ft" ? v * 30.48 : v;
  }
  function toKg(weight, unit) {
    const v = Number(weight);
    if (!Number.isFinite(v)) return null;
    return unit === "lb" ? v * 0.453592 : v;
  }
  
  // Try to generate goals via native Swift code (bypasses CORS)
  function tryGenerateGoalsViaNative() {
    return new Promise((resolve) => {
      console.log("🔵 [tryGenerateGoalsViaNative] Requesting goals generation via native...");
      
      const timeout = setTimeout(() => {
        window.removeEventListener("goals_generated_native", handler);
        console.warn("⚠️ [tryGenerateGoalsViaNative] Timeout waiting for native response");
        resolve({ success: false, error: "Timeout waiting for native response" });
      }, 25000);
      
      const handler = (event) => {
        clearTimeout(timeout);
        window.removeEventListener("goals_generated_native", handler);
        
        const detail = event.detail || {};
        console.log("🔵 [tryGenerateGoalsViaNative] Received native response:", detail);
        
        if (detail.ok === true && detail.goals) {
          console.log("✅ [tryGenerateGoalsViaNative] Native generation successful");
          const goals = detail.goals;
          resolve({
            success: true,
            goals: {
              daily_calories: goals.calories,
              macros: {
                protein_g: goals.proteinG,
                carbs_g: goals.carbsG,
                fat_g: goals.fatG,
                fiber_g: goals.fiberG || null
              }
            }
          });
        } else {
          const error = detail.error || "Unknown error from native";
          console.error("❌ [tryGenerateGoalsViaNative] Native generation failed:", error);
          resolve({ success: false, error: error });
        }
      };
      
      window.addEventListener("goals_generated_native", handler);
      
      // Request native generation
      console.log("🔵 [tryGenerateGoalsViaNative] Posting request to native...");
      postToNative("generate_goals_via_native", { answers: state.answers });
    });
  }

  function calculateAge(birthdate) {
    const birth = new Date(birthdate);
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const m = today.getMonth() - birth.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
    return age;
  }

  // ---- Goals Generation (API) ----
// Uses:
//   POST /calories/goals  (Authorization: Bearer <JWT_TOKEN>)
// Contract: see CALORIES_GOALS_API.md
//
// IMPORTANT:
// - Base URL is hardcoded below (per your request). Change API_BASE_URL to your server.
// - JWT is generated locally in JS using the same HS256 approach as iOS.
//
// Security note: embedding API_TOKEN in a public webpage is not recommended. Since you requested
// "exactly like iOS", this mirrors the iOS behavior.

/** Change this to your server domain (must be https when hosted). */
const API_BASE_URL = "https://app.caloriecount-ai.com";

/** iOS apiToken (HMAC secret) */
const API_TOKEN = "OdIlX0QEIodS2ixLg2v0WFI5Hb7EH9cFDGEaNa94Xts=";

/** localStorage key used by iOS: "auth_user_id" */
const USER_ID_STORAGE_KEY = "auth_user_id";

function getApiBaseUrl() {
  const w = /** @type {any} */ (window);
  const override = (w.ONBOARDING_API_BASE_URL || w.ONBOARDING_CONFIG?.baseUrl || "").toString().trim();
  return (override || API_BASE_URL).replace(/\/$/, "");
}

function generateUserId() {
  // Mimics iOS:
  // uuid lowercased (no hyphens), then: demo_user_<uuid.prefix(8).uppercased()>
  let raw = "";
  if (globalThis.crypto && typeof globalThis.crypto.randomUUID === "function") {
    raw = globalThis.crypto.randomUUID();
  } else {
    // Fallback uuid-ish
    raw = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === "x" ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }
  const compact = raw.toLowerCase().replace(/-/g, "");
  return `demo_user_${compact.slice(0, 8).toUpperCase()}`;
}

function getUserId() {
  const w = /** @type {any} */ (window);
  const override = (w.ONBOARDING_USER_ID || w.ONBOARDING_CONFIG?.userId || w.ONBOARDING_CONFIG?.user_id || "").toString().trim();
  if (override) return override;

  let id = localStorage.getItem(USER_ID_STORAGE_KEY);
  if (!id) {
    id = generateUserId();
    try { localStorage.setItem(USER_ID_STORAGE_KEY, id); } catch (_) {}
  }
  return id;
}

function base64UrlEncodeBytes(bytes) {
  const bin = Array.from(bytes, (b) => String.fromCharCode(b)).join("");
  const b64 = btoa(bin);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlEncodeJson(obj) {
  const json = JSON.stringify(obj);
  const bytes = new TextEncoder().encode(json);
  return base64UrlEncodeBytes(bytes);
}

async function hmacSHA256Bytes(dataBytes, keyStr) {
  if (!globalThis.crypto?.subtle) {
    throw new Error("WebCrypto is not available (crypto.subtle).");
  }
  const keyBytes = new TextEncoder().encode(keyStr);
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sigBuf = await crypto.subtle.sign("HMAC", key, dataBytes);
  return new Uint8Array(sigBuf);
}

async function createJWT(userId, token) {
  // Mirrors iOS:
  // Header: {"alg":"HS256","typ":"JWT"}
  // Payload: {"user_id":..., "iat": now, "exp": now+3600}
  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = { user_id: userId, iat: now, exp: now + 3600 };

  const headerB64 = base64UrlEncodeJson(header);
  const payloadB64 = base64UrlEncodeJson(payload);

  const signingInput = `${headerB64}.${payloadB64}`;
  const sig = await hmacSHA256Bytes(new TextEncoder().encode(signingInput), token);
  const sigB64 = base64UrlEncodeBytes(sig);

  return `${headerB64}.${payloadB64}.${sigB64}`;
}

function kgToLb(kg) { return kg * 2.2046226218; }
function lbToKg(lb) { return lb * 0.45359237; }
function cmToIn(cm) { return cm / 2.54; }
function ftToIn(ft) { return ft * 12.0; }

function mapGoalToApi(goalValue) {
  if (goalValue === "lose_weight") return "Lose";
  if (goalValue === "gain_weight") return "Gain";
  return "Maintain";
}

function mapCoachToApi(coachValue) {
  return coachValue === "yes" ? "Yes" : "No";
}

function mapActivityToApi(activityValue) {
  // API expects extremely_active (not extra_active)
  if (activityValue === "extra_active") return "extremely_active";
  return activityValue || "moderately_active";
}

function mapGoalSpeedToApi(goalSpeedKgPerWeek) {
  // UI captures kg/week (0.1–1.0). API expects an intensity from 1–4.
  const v = Number(goalSpeedKgPerWeek);
  if (!Number.isFinite(v)) return 1;
  if (v <= 0.3) return 1;
  if (v <= 0.6) return 2;
  if (v <= 0.8) return 3;
  return 4;
}

function isoFromDateInput(dateStr) {
  // input type="date" gives YYYY-MM-DD
  const d = new Date(dateStr);
  if (String(d) === "Invalid Date") return null;
  return d.toISOString();
}

function buildGoalsApiPayload() {
  const userId = getUserId();
  const gender = (state.answers["gender"]?.value || "male").toLowerCase();

  const hw = state.answers["height_weight"] || {};
  const weightUnitUi = (hw["weight__unit"] || "kg").toLowerCase(); // kg | lb
  const heightUnitUi = (hw["height__unit"] || "cm").toLowerCase(); // cm | ft

  const weightVal = Number(hw.weight);
  const heightVal = Number(hw.height);

  const weightUnitApi = weightUnitUi === "lb" ? "lbs" : "kg";
  const heightUnitApi = heightUnitUi === "ft" ? "in" : "cm";

  const weightValueApi = Number.isFinite(weightVal) ? weightVal : (weightUnitUi === "lb" ? 154 : 70);
  const heightValueApi = (() => {
    if (!Number.isFinite(heightVal)) return heightUnitApi === "in" ? 70 : 170;
    if (heightUnitUi === "ft") return ftToIn(heightVal);
    return heightVal;
  })();

  // desired_weight:
  // - Slider UI is always kg, but API requires it in the SAME unit as current weight.
  const dw = state.answers["desired_weight"] || {};
  const desiredWeightKg = Number(dw.value);
  let desiredWeightApi = Number.isFinite(desiredWeightKg) ? desiredWeightKg : (weightUnitUi === "lb" ? lbToKg(weightValueApi) : weightValueApi);
  if (weightUnitUi === "lb") desiredWeightApi = kgToLb(desiredWeightApi);
  desiredWeightApi = Math.round(desiredWeightApi * 10) / 10;

  const goalValue = state.answers["goal"]?.value || "maintain";
  const goalApi = mapGoalToApi(goalValue);

  const goalSpeedKgPerWeek = state.answers["goal_speed"]?.value ?? 0.5;
  const goalSpeedApi = mapGoalSpeedToApi(goalSpeedKgPerWeek);

  const activityValue = state.answers["activity_level"]?.value || "moderately_active";
  const activityApi = mapActivityToApi(activityValue);

  const birthdateStr = state.answers["birthdate"]?.birthdate;
  const birthIso = birthdateStr ? isoFromDateInput(birthdateStr) : null;

  const coachValue = state.answers["coach"]?.value || "no";
  const coachApi = mapCoachToApi(coachValue);

  const notifications = false; // UI step is informational; can be enabled later.

  /** @type {any} */
  const payload = {
    user_id: userId,
    gender,
    desired_weight: desiredWeightApi,
    height_weight: {
      weight: { value: weightValueApi, unit: weightUnitApi },
      height: { value: heightValueApi, unit: heightUnitApi },
    },
    goal: goalApi,
    goal_speed: goalSpeedApi,
    activity_level: activityApi,
    birthdate: { birthdate: birthIso || new Date().toISOString() },
    notifications,
    coach: coachApi,
  };

  return payload;
}

async function generateGoalsViaApi() {
  const baseUrl = getApiBaseUrl();
  const userId = getUserId();
  const jwtToken = await createJWT(userId, API_TOKEN);

  const url = `${String(baseUrl).replace(/\/$/, "")}/calories/goals?user_id=${encodeURIComponent(userId)}`;
  const payload = buildGoalsApiPayload();

  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort(), 20000);

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${jwtToken}`,
      },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });

    const json = await res.json().catch(() => null);

    if (!res.ok) {
      const msg = (json && json.error) ? json.error : `Request failed (${res.status})`;
      throw new Error(msg);
    }
    if (!json || json.ok !== true || !json.goals) {
      throw new Error("Unexpected response format.");
    }

    // normalize to the UI's expected keys
    const g = json.goals || {};
    const m = g.macros || {};

    return {
      daily_calories: g.daily_calories,
      macros: {
        protein_g: m.protein_g,
        carbs_g: m.carbs_g,
        fat_g: m.fat_g,
        fiber_g: m.fiber_g,
      },
      bmi: g.bmi,
      bmr: g.bmr,
      tdee: g.tdee,
      calorie_adjustment: g.calorie_adjustment,
      time_to_goal_weeks: g.time_to_goal_weeks,
      notes: g.notes,
      _raw: json,
      _api_url: url,
    };
  } finally {
    clearTimeout(timeout);
  }
}

  // ---- DOM ----
  const content = document.getElementById("content");
  const footer = document.getElementById("footer");
  const backBtn = document.getElementById("backBtn");
  const skipBtn = document.getElementById("skipBtn");
  const topbar = document.getElementById("topbar");
  const progressWrap = document.getElementById("progressWrap");

  const progressFill = document.getElementById("progressFill");
  const progressText = document.getElementById("progressText");
  const progressSteps = document.getElementById("progressSteps");
  const stepMeta = document.getElementById("stepMeta");

  // ---- Rendering ----
  function render() {
    const step = byId.get(state.currentId);
    if (!step) return;

    const isGenerating = step.type === "goals_generation";

    topbar.classList.toggle("hidden", isGenerating);
    progressWrap.classList.toggle("hidden", isGenerating);

    const idx = order.indexOf(step.id);
    const total = order.length;
    const pct = Math.round((idx / (total - 1)) * 100);

    progressFill.style.width = `${clamp(pct, 0, 100)}%`;
    progressText.textContent = `${clamp(pct, 0, 100)}%`;
    progressSteps.textContent = `${idx + 1} / ${total}`;
    stepMeta.textContent = `Step ${idx + 1} of ${total}`;

    backBtn.disabled = state.stack.length === 0;
    skipBtn.style.visibility = step.optional ? "visible" : "hidden";

    content.innerHTML = "";
    footer.innerHTML = "";

    const wrap = document.createElement("div");
    wrap.className = "fadeIn";

    if (step.type !== "goals_generation") {
      const h1 = document.createElement("h1");
      h1.textContent = step.title;
      wrap.appendChild(h1);

      if (step.description) {
        const p = document.createElement("p");
        p.className = "desc";
        p.textContent = step.description;
        wrap.appendChild(p);
      }
    }

    if (step.type === "form") {
      wrap.appendChild(renderForm(step));
      renderFooterButtons(step, { showPrimary: true });
    } else if (step.type === "question") {
      wrap.appendChild(renderQuestion(step));
      renderFooterButtons(step, { showPrimary: true });
    } else if (step.type === "info") {
      wrap.appendChild(renderInfo(step));
      renderFooterButtons(step, { showPrimary: true, primaryTitle: "Continue" });
    } else if (step.type === "goals_generation") {
      wrap.appendChild(renderGoalsGeneration(step));
    } else {
      const p = document.createElement("p");
      p.className = "desc";
      p.textContent = "Unsupported step type.";
      wrap.appendChild(p);
      renderFooterButtons(step, { showPrimary: true });
    }

    content.appendChild(wrap);

    setTimeout(() => {
      const first = content.querySelector("input, button.opt");
      if (first && step.type === "form") first.focus({ preventScroll: true });
    }, 80);

    updatePrimaryEnabled(step);
  }

  function renderForm(step) {
    const fieldsWrap = document.createElement("div");
    fieldsWrap.className = "fields";

    const saved = state.answers[step.id] || {};

    step.fields.forEach((field) => {
      const fieldEl = document.createElement("div");
      fieldEl.className = "field";
      fieldEl.dataset.fieldId = field.id;

      const labelRow = document.createElement("div");
      labelRow.className = "labelRow";

      const label = document.createElement("label");
      label.textContent = field.label;
      label.setAttribute("for", `in_${step.id}_${field.id}`);

      const req = document.createElement("span");
      req.className = "req";
      req.textContent = field.required ? "Required" : "Optional";

      labelRow.appendChild(label);
      labelRow.appendChild(req);

      const control = document.createElement("div");
      control.className = "control";

      const input = document.createElement("input");
      input.id = `in_${step.id}_${field.id}`;
      input.name = field.id;
      input.type = field.input.type;
      input.placeholder = field.input.placeholder || "";

      if (field.input.type === "number") {
        input.inputMode = "decimal";
        input.autocomplete = "off";
      }
      if (field.input.type === "date") {
        input.autocomplete = "bday";
      }

      input.value = saved[field.id] ?? "";
      control.appendChild(input);

      let unitSelect = null;
      if (field.input.unitOptions && field.input.unitOptions.length) {
        unitSelect = document.createElement("select");
        unitSelect.setAttribute("aria-label", `${field.label} units`);
        const savedUnitKey = `${field.id}__unit`;
        const unitValue = saved[savedUnitKey] || field.input.defaultUnit || field.input.unitOptions[0];

        field.input.unitOptions.forEach((u) => {
          const opt = document.createElement("option");
          opt.value = u;
          opt.textContent = u;
          if (u === unitValue) opt.selected = true;
          unitSelect.appendChild(opt);
        });
        control.appendChild(unitSelect);
      }

      const error = document.createElement("div");
      error.className = "error";
      error.textContent = `Please enter your ${field.label.toLowerCase()}.`;

      const onChange = () => {
        const obj = state.answers[step.id] || {};
        obj[field.id] = input.value;
        if (unitSelect) obj[`${field.id}__unit`] = unitSelect.value;
        state.answers[step.id] = obj;
        validateStep(step, { soft: true });
        updatePrimaryEnabled(step);
      };

      input.addEventListener("input", onChange);
      input.addEventListener("change", onChange);
      if (unitSelect) unitSelect.addEventListener("change", onChange);

      fieldEl.appendChild(labelRow);
      fieldEl.appendChild(control);

      if (field.id === "height" && unitSelect) {
        const hint = document.createElement("div");
        hint.className = "hint";
        hint.textContent = "Tip: use cm for best accuracy.";
        fieldEl.appendChild(hint);
      }
      if (field.id === "weight" && unitSelect) {
        const hint = document.createElement("div");
        hint.className = "hint";
        hint.textContent = "You can change units anytime.";
        fieldEl.appendChild(hint);
      }

      fieldEl.appendChild(error);
      fieldsWrap.appendChild(fieldEl);
    });

    return fieldsWrap;
  }

  function renderQuestion(step) {
    const saved = state.answers[step.id] || {};

    if (step.input.type === "gender_select") {
      const options = document.createElement("div");
      options.className = "options genderOpts";

      step.input.options.forEach((optText) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "opt";
        btn.setAttribute("role", "radio");
        btn.setAttribute("aria-checked", "false");

        const icon = document.createElement("div");
        icon.className = "genderIcon";
        icon.textContent = optText === "Male" ? "👨" : "👩";

        const strong = document.createElement("strong");
        strong.textContent = optText;

        const right = document.createElement("div");
        right.className = "pill";
        const dot = document.createElement("i");
        right.appendChild(dot);

        btn.appendChild(icon);
        btn.appendChild(strong);
        btn.appendChild(right);

        const isSelected = saved.value === optText.toLowerCase();
        if (isSelected) {
          btn.classList.add("selected");
          btn.setAttribute("aria-checked", "true");
        }

        btn.addEventListener("click", () => {
          state.answers[step.id] = { value: optText.toLowerCase() };
          [...options.querySelectorAll(".opt")].forEach((el) => {
            el.classList.remove("selected");
            el.setAttribute("aria-checked", "false");
          });
          btn.classList.add("selected");
          btn.setAttribute("aria-checked", "true");
          updatePrimaryEnabled(step);
          setTimeout(() => goNext(), 160);
        });

        options.appendChild(btn);
      });

      options.setAttribute("role", "radiogroup");
      options.setAttribute("aria-label", step.title);
      return options;
    }

    if (step.input.type === "single_select") {
      const options = document.createElement("div");
      options.className = "options" + (step.id === "activity_level" ? " activityOpts" : "");

      const opts = step.input.options;
      opts.forEach((opt) => {
        const isObject = typeof opt === "object";
        const optValue = isObject ? opt.value : opt;
        const optLabel = isObject ? opt.label : opt;
        const optSub = isObject ? opt.sub : null;

        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "opt";
        btn.setAttribute("role", "radio");
        btn.setAttribute("aria-checked", "false");

        const left = document.createElement("div");
        const strong = document.createElement("strong");
        strong.textContent = optLabel;
        left.appendChild(strong);

        if (optSub) {
          const sub = document.createElement("div");
          sub.className = "sub";
          sub.textContent = optSub;
          left.appendChild(sub);
        }

        const right = document.createElement("div");
        right.className = "pill";
        const dot = document.createElement("i");
        right.appendChild(dot);

        btn.appendChild(left);
        btn.appendChild(right);

        const isSelected = saved.value === optValue;
        if (isSelected) {
          btn.classList.add("selected");
          btn.setAttribute("aria-checked", "true");
        }

        btn.addEventListener("click", () => {
          state.answers[step.id] = { value: optValue };
          [...options.querySelectorAll(".opt")].forEach((el) => {
            el.classList.remove("selected");
            el.setAttribute("aria-checked", "false");
          });
          btn.classList.add("selected");
          btn.setAttribute("aria-checked", "true");
          updatePrimaryEnabled(step);
          setTimeout(() => goNext(), 160);
        });

        options.appendChild(btn);
      });

      options.setAttribute("role", "radiogroup");
      options.setAttribute("aria-label", step.title);
      return options;
    }
    if (step.input.type === "slider") {
      const savedVal = (saved.value != null) ? Number(saved.value) : null;

      // Base slider config from step (may be overridden for desired_weight)
      let sliderMin = Number(step.input.min);
      let sliderMax = Number(step.input.max);
      let sliderStep = Number(step.input.step);
      let sliderUnit = String(step.input.unit || "");

      // Compute a default based on the (possibly overridden) range
      const defaultVal = (step.input.default != null)
        ? Number(step.input.default)
        : (sliderMin + ((sliderMax - sliderMin) * 0.5));

      let initial = (savedVal != null && Number.isFinite(savedVal)) ? savedVal : defaultVal;

      if (step.id === "desired_weight") {
        const hw = state.answers["height_weight"] || {};
        const weightUnit = String(hw["weight__unit"] || "kg").toLowerCase(); // kg | lb
        const weightVal = Number(hw.weight);

        if (weightUnit === "lb") {
          sliderUnit = "lb";
          sliderMin = Math.round(Number(step.input.min) * 2.2046226218);
          sliderMax = Math.round(Number(step.input.max) * 2.2046226218);
          sliderStep = 1;
        } else {
          sliderUnit = "kg";
        }

        // Prefill from current weight in the selected unit
        if (Number.isFinite(weightVal) && weightVal > 0) {
          initial = (savedVal != null && Number.isFinite(savedVal)) ? savedVal : weightVal;
        }

        initial = clamp(initial, sliderMin, sliderMax);
      }

      const wrap = document.createElement("div");
      wrap.className = "sliderWrap";

      const head = document.createElement("div");
      head.className = "sliderHead";

      const left = document.createElement("div");
      left.style.color = "var(--muted)";
      left.style.fontSize = "13px";
      left.textContent = step.id === "desired_weight" ? "Your target weight" : "Adjust to your preference";

      const right = document.createElement("div");
      const val = document.createElement("span");
      val.className = "valueBubble";
      val.textContent = fmtNumber(initial, sliderStep);

      const unit = document.createElement("span");
      unit.className = "unit";
      unit.textContent = sliderUnit;

      right.appendChild(val);
      right.appendChild(unit);

      head.appendChild(left);
      head.appendChild(right);

      const range = document.createElement("input");
      range.type = "range";
      range.min = String(sliderMin);
      range.max = String(sliderMax);
      range.step = String(sliderStep);
      range.value = String(initial);

      const hint = document.createElement("div");
      hint.className = "hint";
      hint.textContent = (step.id === "goal_speed")
        ? "Tip: 0.5 kg/week is a healthy, sustainable pace."
        : `Range: ${sliderMin}–${sliderMax} ${sliderUnit}`;

      const storeValue = (v) => {
        if (step.id === "desired_weight") state.answers[step.id] = { value: Number(v), unit: sliderUnit };
        else state.answers[step.id] = { value: Number(v) };
      };

      range.addEventListener("input", () => {
        val.textContent = fmtNumber(range.value, sliderStep);
        storeValue(range.value);
        updatePrimaryEnabled(step);
      });

      storeValue(initial);

      wrap.appendChild(head);
      wrap.appendChild(range);
      wrap.appendChild(hint);
      return wrap;
    }

    if (step.input.type === "text") {
      const savedText = saved.value ?? "";
      const fieldEl = document.createElement("div");
      fieldEl.className = "field";

      const labelRow = document.createElement("div");
      labelRow.className = "labelRow";

      const label = document.createElement("label");
      label.textContent = "Referral code";
      label.setAttribute("for", `in_${step.id}_ref`);

      const req = document.createElement("span");
      req.className = "req";
      req.textContent = step.optional ? "Optional" : "Required";

      labelRow.appendChild(label);
      labelRow.appendChild(req);

      const control = document.createElement("div");
      control.className = "control";

      const input = document.createElement("input");
      input.id = `in_${step.id}_ref`;
      input.type = "text";
      input.placeholder = step.input.placeholder || "Referral code";
      input.autocapitalize = "characters";
      input.autocomplete = "off";
      input.value = savedText;

      input.addEventListener("input", () => {
        state.answers[step.id] = { value: input.value.trim() };
        updatePrimaryEnabled(step);
      });

      control.appendChild(input);

      const hint = document.createElement("div");
      hint.className = "hint";
      hint.textContent = "If you don't have one, you can skip."; /* FIXED */

      fieldEl.appendChild(labelRow);
      fieldEl.appendChild(control);
      fieldEl.appendChild(hint);

      state.answers[step.id] = { value: savedText };

      return fieldEl;
    }

    const p = document.createElement("p");
    p.className = "desc";
    p.textContent = "Unsupported question input.";
    return p;
  }

  function renderInfo(step) {
    const frag = document.createDocumentFragment();

    const hero = document.createElement("div");
    hero.className = "hero";
    const badge = document.createElement("div");
    badge.className = "heroBadge";
    badge.textContent = "Quick note";
    hero.appendChild(badge);

    frag.appendChild(hero);

    const extra = document.createElement("p");
    extra.className = "desc";
    extra.style.marginTop = "10px";
    extra.textContent = "We'll keep things lightweight — only the reminders you want."; /* FIXED */
    frag.appendChild(extra);

    return frag;
  }

  function renderGoalsGeneration(step) {
    const wrap = document.createElement("div");
    wrap.className = "goalsGenWrap";

    const loadingDiv = document.createElement("div");
    loadingDiv.id = "goalsLoading";

    const circles = document.createElement("div");
    circles.className = "loadingCircles";
    circles.innerHTML = `
      <div class="ring ring1"></div>
      <div class="ring ring2"></div>
      <div class="ring ring3"></div>
      <div class="centerIcon">✨</div>
    `;

    const title = document.createElement("h1");
    title.textContent = "Generating your plan";
    title.style.marginTop = "16px";

    const statusEl = document.createElement("div");
    statusEl.className = "loadingStatus";
    statusEl.id = "loadingStatus";
    statusEl.textContent = "Analyzing your profile...";

    loadingDiv.appendChild(circles);
    loadingDiv.appendChild(title);
    loadingDiv.appendChild(statusEl);
    wrap.appendChild(loadingDiv);

    const resultsDiv = document.createElement("div");
    resultsDiv.id = "goalsResults";
    resultsDiv.style.display = "none";
    resultsDiv.style.width = "100%";
    wrap.appendChild(resultsDiv);

    setTimeout(() => startGoalsGeneration(), 100);
    return wrap;
  }
  function startGoalsGeneration() {
    const statusEl = document.getElementById("loadingStatus");
    const messages = [
      "Analyzing your profile...",
      "Preparing your request...",
      "Generating your goals...",
      "Finalizing..."
    ];

    let msgIndex = 0;
    const msgInterval = setInterval(() => {
      msgIndex++;
      if (msgIndex < messages.length && statusEl) statusEl.textContent = messages[msgIndex];
    }, 650);

    (async () => {
      // Try native first (bypasses CORS)
      console.log("🔵 [startGoalsGeneration] Attempting to generate goals via native...");
      const nativeResult = await tryGenerateGoalsViaNative();
      
      if (nativeResult.success) {
        console.log("✅ [startGoalsGeneration] Goals generated successfully via native");
        const apiGoals = nativeResult.goals;
        
        // Map API response to the UI's expected keys
        const g = apiGoals || {};
        const m = g.macros || {};

        state.generatedGoals = {
          calories: Math.round(Number(g.daily_calories || g.calories || 0)),
          proteinG: Math.round(Number(m.protein_g || g.proteinG || 0)),
          carbsG: Math.round(Number(m.carbs_g || g.carbsG || 0)),
          fatG: Math.round(Number(m.fat_g || g.fatG || 0)),

          // Keep extra fields
          fiberG: Number(m.fiber_g || g.fiberG) ?? null,
          bmi: g.bmi ?? null,
          bmr: g.bmr ?? null,
          tdee: g.tdee ?? null,
          calorie_adjustment: g.calorie_adjustment ?? null,
          time_to_goal_weeks: g.time_to_goal_weeks ?? null,
          notes: g.notes ?? null,
          _raw: g._raw ?? null,
        };

        // Keep normalized (metric) values for convenience
        const hw = state.answers["height_weight"] || {};
        const heightVal = hw.height ?? 170;
        const heightUnit = hw["height__unit"] || "cm";
        const weightVal = hw.weight ?? 70;
        const weightUnit = hw["weight__unit"] || "kg";

        state.answers._normalized = {
          height_cm: toCm(heightVal, heightUnit),
          weight_kg: toKg(weightVal, weightUnit),
        };

        clearInterval(msgInterval);
        showGoalsResults(state.generatedGoals);

        console.log("✅ [Goals API] Goals generated successfully, posting to native");
        postToNative("goals_generated", { ok: true, goals: state.generatedGoals });
        return; // Exit early, don't try JavaScript API
      } else {
        console.warn("⚠️ [startGoalsGeneration] Native generation failed, falling back to JavaScript API");
        console.warn("⚠️ [startGoalsGeneration] Error: ", nativeResult.error);
      }
      
      // Fallback to JavaScript API if native fails
      try {
        console.log("🔵 [startGoalsGeneration] Calling generateGoalsViaApi()...");
        const apiGoals = await generateGoalsViaApi();

        // Map API response to the UI's expected keys
        const g = apiGoals || {};
        const m = g.macros || {};

        state.generatedGoals = {
          calories: Math.round(Number(g.daily_calories) || 0),
          proteinG: Math.round(Number(m.protein_g) || 0),
          carbsG: Math.round(Number(m.carbs_g) || 0),
          fatG: Math.round(Number(m.fat_g) || 0),

          // Keep extra fields (not shown in UI but useful for app logic)
          fiberG: Number(m.fiber_g) ?? null,
          bmi: g.bmi ?? null,
          bmr: g.bmr ?? null,
          tdee: g.tdee ?? null,
          calorie_adjustment: g.calorie_adjustment ?? null,
          time_to_goal_weeks: g.time_to_goal_weeks ?? null,
          notes: g.notes ?? null,
          _raw: g._raw ?? null,
        };

        // Keep normalized (metric) values for convenience
        const hw = state.answers["height_weight"] || {};
        const heightVal = hw.height ?? 170;
        const heightUnit = hw["height__unit"] || "cm";
        const weightVal = hw.weight ?? 70;
        const weightUnit = hw["weight__unit"] || "kg";

        state.answers._normalized = {
          height_cm: toCm(heightVal, heightUnit),
          weight_kg: toKg(weightVal, weightUnit),
        };

        clearInterval(msgInterval);
        showGoalsResults(state.generatedGoals);

        postToNative("goals_generated", { ok: true, goals: state.generatedGoals });
      } catch (err) {
        clearInterval(msgInterval);
        const msg = (err && err.name === "AbortError")
          ? "Request timed out. Please try again."
          : (err && err.message) ? err.message : "Something went wrong.";
        console.warn("[Goals API error]", err);
        postToNative("goals_generated", { ok: false, error: msg });
        showGoalsError(msg, `${getApiBaseUrl()}/calories/goals`);
      }
    })();
  }
function showGoalsResults(goals) {
  const loadingEl = document.getElementById("goalsLoading");
  const resultsEl = document.getElementById("goalsResults");

  if (loadingEl) loadingEl.style.display = "none";
  if (!resultsEl) return;

  const calories = goals.calories ?? goals.daily_calories ?? goals.dailyCalories ?? 0;
  const proteinG = goals.proteinG ?? goals.macros?.protein_g ?? goals.macros?.proteinG ?? 0;
  const carbsG = goals.carbsG ?? goals.macros?.carbs_g ?? goals.macros?.carbsG ?? 0;
  const fatG = goals.fatG ?? goals.macros?.fat_g ?? goals.macros?.fatG ?? 0;

  resultsEl.style.display = "block";
  resultsEl.innerHTML = `
    <div class="successCheck">✓</div>
    <h1 style="margin-top:16px;">Your personalized goals</h1>
    <p class="desc">Based on your profile and preferences</p>

    <div class="goalsCards">
      <div class="goalCard">
        <div class="goalIcon calories">🔥</div>
        <div class="goalInfo">
          <div class="label">Daily Calories</div>
          <div class="value">${calories}<span class="unit">kcal</span></div>
        </div>
      </div>

      <div class="macrosRow">
        <div class="goalCard">
          <div class="goalIcon protein">🥩</div>
          <div class="goalInfo">
            <div class="label">Protein</div>
            <div class="value">${proteinG}<span class="unit">g</span></div>
          </div>
        </div>
        <div class="goalCard">
          <div class="goalIcon carbs">🌾</div>
          <div class="goalInfo">
            <div class="label">Carbs</div>
            <div class="value">${carbsG}<span class="unit">g</span></div>
          </div>
        </div>
        <div class="goalCard">
          <div class="goalIcon fat">🥑</div>
          <div class="goalInfo">
            <div class="label">Fat</div>
            <div class="value">${fatG}<span class="unit">g</span></div>
          </div>
        </div>
      </div>
    </div>
  `;

  renderFooterButtons(byId.get("generating"), { showPrimary: true, primaryTitle: "Get Started" });
}

function showGoalsError(message, apiUrl) {
  const loadingEl = document.getElementById("goalsLoading");
  const resultsEl = document.getElementById("goalsResults");

  if (loadingEl) loadingEl.style.display = "none";
  if (!resultsEl) return;

  resultsEl.style.display = "block";
  resultsEl.innerHTML = `
    <div class="successCheck" style="background: linear-gradient(135deg, rgba(255,90,122,.18), rgba(255,90,122,.08));">!</div>
    <h1 style="margin-top:16px;">Couldn't generate goals</h1>
    <p class="desc" style="margin-bottom:4px;">Load failed</p>
    <p class="desc" style="margin-top:0;margin-bottom:12px;">${String(message || "Please try again.").replace(/</g, "&lt;")}</p>
    <p class="desc" style="color: var(--muted2); font-size: 12px; margin-top:0;">API: ${String(apiUrl || "").replace(/</g, "&lt;")}</p>
  `;

  footer.innerHTML = "";
  const retry = document.createElement("button");
  retry.className = "btn primary";
  retry.type = "button";
  retry.textContent = "Try Again";
  retry.addEventListener("click", () => {
    state.currentId = "generating";
    render();
  });
  footer.appendChild(retry);
}

  function renderFooterButtons(step, { showPrimary, primaryTitle } = {}) {
    const primary = document.createElement("button");
    primary.className = "btn primary";
    primary.type = "button";

    primary.textContent = primaryTitle || (step.next ? "Continue" : "Finish");
    primary.addEventListener("click", () => {
      if (step.type === "goals_generation") {
        finish();
        return;
      }
      const ok = validateStep(step, { soft: false });
      if (!ok) return;
      goNext();
    });

    let secondary = null;
    if (step.optional) {
      secondary = document.createElement("button");
      secondary.className = "btn ghost";
      secondary.type = "button";
      secondary.textContent = "Skip";
      secondary.addEventListener("click", () => {
        delete state.answers[step.id];
        goNext();
      });
    }

    if (secondary) footer.appendChild(secondary);
    if (showPrimary) footer.appendChild(primary);

    footer.dataset.primaryId = "primary";
    primary.dataset.role = "primary";
  }

  // ---- Validation ----
  function validateStep(step, { soft }) {
    if (step.type !== "form") return true;

    let ok = true;
    const saved = state.answers[step.id] || {};

    step.fields.forEach((field) => {
      const fieldEl = content.querySelector(`.field[data-field-id="${field.id}"]`);
      const val = (saved[field.id] ?? "").toString().trim();

      const required = !!field.required;
      const isEmpty = val.length === 0;

      let invalid = false;
      if (required && isEmpty) invalid = true;

      if (!isEmpty && field.input.type === "number") {
        const num = Number(val);
        if (!Number.isFinite(num) || num <= 0) invalid = true;
      }
      if (!isEmpty && field.input.type === "date") {
        const d = new Date(val);
        if (String(d) === "Invalid Date") invalid = true;
      }

      if (invalid) ok = false;

      if (fieldEl) {
        if (!soft) fieldEl.classList.toggle("invalid", invalid);
        else if (!invalid) fieldEl.classList.remove("invalid");
      }
    });

    return ok;
  }

  function updatePrimaryEnabled(step) {
    const primary = footer.querySelector('[data-role="primary"]');
    if (!primary) return;

    let enabled = true;

    if (step.type === "form") {
      enabled = validateStep(step, { soft: true });
    } else if (step.type === "question") {
      const a = state.answers[step.id];
      if (step.input.type === "single_select" || step.input.type === "gender_select") {
        enabled = !!(a && a.value);
      } else if (step.input.type === "slider") {
        enabled = !!(a && a.value != null);
      } else if (step.input.type === "text") {
        enabled = step.optional ? true : !!(a && a.value && a.value.trim().length);
      }
    } else if (step.type === "info") {
      enabled = true;
    } else if (step.type === "goals_generation") {
      enabled = !!state.generatedGoals;
    }

    primary.disabled = !enabled;
  }

  // ---- Navigation ----
  function goTo(stepId) {
    const step = byId.get(stepId);
    if (!step) return;
    state.currentId = stepId;
    render();
    postToNative("step_view", { stepId });
  }

  function goNext() {
    const step = byId.get(state.currentId);
    if (!step) return;

    if (!step.next) {
      finish();
      return;
    }

    state.stack.push(step.id);

    if (step.id === "height_weight") {
      const a = state.answers[step.id] || {};
      const h = a.height, hu = a["height__unit"] || "cm";
      const w = a.weight, wu = a["weight__unit"] || "kg";
      const cm = toCm(h, hu);
      const kg = toKg(w, wu);
      state.answers._normalized = state.answers._normalized || {};
      state.answers._normalized.height_cm = cm;
      state.answers._normalized.weight_kg = kg;
    }

    goTo(step.next);
  }

  function goBack() {
    const prev = state.stack.pop();
    if (!prev) return;
    goTo(prev);
  }

  function finish() {
    const payload = {
      answers: state.answers,
      goals: state.generatedGoals,
      completedAt: new Date().toISOString(),
    };

    postToNative("complete", payload);

    content.innerHTML = `
      <div class="fadeIn goalsGenWrap">
        <div class="successCheck">🎉</div>
        <h1>All set!</h1>
        <p class="desc">Your personalized plan is ready. Let's get started!</p>
      </div>
    `;
    footer.innerHTML = "";
    topbar.classList.add("hidden");
    progressWrap.classList.add("hidden");

    console.log("[Onboarding complete]", payload);
  }

  // ---- Topbar events ----
  backBtn.addEventListener("click", goBack);
  skipBtn.addEventListener("click", () => {
    const step = byId.get(state.currentId);
    if (step && step.optional) {
      delete state.answers[step.id];
      goNext();
    }
  });

  // ---- Init ----
  render();
  postToNative("ready", { firstStepId: state.currentId });

  window.OnboardingWeb = {
    getState: () => JSON.parse(JSON.stringify(state)),
    setAnswers: (answersObj) => { state.answers = answersObj || {}; render(); },
    goTo: (stepId) => goTo(stepId),
    finish: () => finish(),
  };
})();
