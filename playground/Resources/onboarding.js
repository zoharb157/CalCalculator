// @ts-check
/**
 * Onboarding Flow - JavaScript Implementation
 * 
 * Follows company standard pattern for events and macros:
 * - Uses call/callAsync for native communication
 * - Implements __handleEvent__ pattern for Swift-to-JS communication
 * - Uses eventById map for async callback tracking
 */

(() => {
  // ============================================================================
  // CONSTANTS & CONFIGURATION
  // ============================================================================
  
  /** @type {string} */
  const VERSION = "1.0.0";
  
  /** @type {string} */
  let CID = typeof window !== "undefined" && window.CID ? String(window.CID) : "";
  
  /** @type {string} */
  let SESSION_ID = typeof window !== "undefined" && window.SESSION_ID ? String(window.SESSION_ID) : "";
  
  /** @type {boolean} */
  let ISSUBSCRIBESERVER = false;
  
  /** @type {string} */
  let USERID = typeof window !== "undefined" && window.USERID ? String(window.USERID) : "";
  
  /** @type {string} */
  let APP_VERSION = typeof window !== "undefined" && window.APP_VERSION ? String(window.APP_VERSION) : "1.0";
  
  /** @type {string} */
  let INSTALL_TIME = "";
  
  /** @type {number} */
  let SECONDS = 0;
  
  // Onboarding completion tracking
  const ONBOARDING_COMPLETED_KEY = 'caloriecount_onboarding_completed';
  
  // ============================================================================
  // DATA
  // ============================================================================
  
  // ---- Data (your onboarding steps) ----
  // Updated flow: gender -> name_input -> welcome -> ... -> permissions (last) -> generating
  const STEPS = [
    {
      id: "gender",
      type: "question",
      title: "What's your biological sex?",
      description: "This helps us calculate your metabolism accurately.",
      input: { type: "gender_select", options: ["Male", "Female"] },
      next: "name_input",
    },
    {
      id: "name_input",
      type: "name_input",
      title: "What's your name?",
      description: "Let's personalize your experience.",
      next: "welcome",
    },
    {
      id: "welcome",
      type: "welcome",
      title: "Welcome",
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
      fields: [{ id: "birthdate", label: "Birthdate", required: true, input: { type: "date", defaultValue: "2000-01-01" } }],
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
          { value: "sedentary", label: "Sedentary", sub: "Little to no exercise, desk job", icon: "🪑" },
          { value: "lightly_active", label: "Lightly Active", sub: "Light exercise 1-3 days/week", icon: "🚶" },
          { value: "moderately_active", label: "Moderately Active", sub: "Moderate exercise 3-5 days/week", icon: "🏃" },
          { value: "very_active", label: "Very Active", sub: "Hard exercise 6-7 days/week", icon: "💪" },
          { value: "extra_active", label: "Extra Active", sub: "Very hard exercise, physical job", icon: "🏋️" },
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
          { value: "lose_weight", label: "Lose weight", sub: "Reduce calories gradually", icon: "📉" },
          { value: "maintain", label: "Maintain", sub: "Keep a steady intake", icon: "⚖️" },
          { value: "gain_weight", label: "Gain weight", sub: "Support lean gain", icon: "📈" },
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
          { value: "yes", label: "Yes", sub: "We'll align with your guidance", icon: "👨‍🏫" },
          { value: "no", label: "No", sub: "We'll guide you step-by-step", icon: "🤖" },
        ],
      },
      next: "tracking_permission",
    },
    {
      id: "tracking_permission",
      type: "permission",
      permissionType: "tracking",
      title: "Help Us Personalize Your Experience",
      description: "We use app tracking to understand how you use the app and show you relevant content.",
      icon: "📊",
      benefits: [
        { icon: "🎯", text: "Personalized recommendations based on your goals" },
        { icon: "📈", text: "Better insights into your progress" },
        { icon: "🔒", text: "Your data stays private and secure" },
      ],
      next: "notifications_permission",
    },
    {
      id: "notifications_permission",
      type: "permission",
      permissionType: "notifications",
      title: "Stay On Track",
      description: "Get timely reminders to log your meals and track your progress.",
      icon: "🔔",
      benefits: [
        { icon: "⏰", text: "Meal logging reminders" },
        { icon: "🏆", text: "Goal achievement celebrations" },
        { icon: "💪", text: "Daily motivation tips" },
      ],
      next: "generating",
    },
    {
      id: "generating",
      type: "goals_generation",
      title: "Generating your plan",
      next: null, // No more landing pages - finish here
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
    navigationDirection: "forward", // Track navigation direction for animations
    permissions: {
      tracking: null, // null = not asked, true = allowed, false = declined
      notifications: null,
    },
  };

  // Minimum age requirement
  const MIN_AGE = 13;

  // ============================================================================
  // ONBOARDING COMPLETION TRACKING
  // ============================================================================
  
  /**
   * Check if user has completed onboarding before
   * @returns {boolean}
   */
  const hasCompletedOnboarding = () => {
    try {
      const completed = localStorage.getItem(ONBOARDING_COMPLETED_KEY);
      return completed === 'true';
    } catch (error) {
      return false;
    }
  };
  
  /**
   * Mark onboarding as completed (called when user reaches paywall/generating step)
   */
  const setOnboardingCompleted = () => {
    try {
      localStorage.setItem(ONBOARDING_COMPLETED_KEY, 'true');
      sendPostRequest("onboarding_marked_completed", '', false);
    } catch (error) {
      // Silently fail if localStorage is not available
    }
  };
  
  /**
   * Skip directly to generating/paywall step (for returning users)
   */
  const skipToPaywall = () => {
    sendPostRequest("returning_user_skip_to_paywall", '', false);
    state.currentId = "generating";
    
    // Try to load saved answers from localStorage
    try {
      const savedAnswers = localStorage.getItem('caloriecount_onboarding_answers');
      if (savedAnswers) {
        state.answers = JSON.parse(savedAnswers);
        sendPostRequest("loaded_saved_answers", '', false);
      }
    } catch (error) {
      // Use empty answers if loading fails
    }
    
    render();
  };
  
  /**
   * Save answers to localStorage (for future sessions)
   */
  const saveAnswersToStorage = () => {
    try {
      localStorage.setItem('caloriecount_onboarding_answers', JSON.stringify(state.answers));
    } catch (error) {
      // Silently fail
    }
  };

  // ============================================================================
  // NATIVE BRIDGE - Company Standard Pattern
  // ============================================================================
  
  /** @type {string} */
  const swiftEndPoint = "onboarding";
  
  /** @type {Object.<string, Callback>} */
  const eventById = {};
  
  /** @typedef {{( data: any | undefined, error: string | undefined): void}} Callback */
  
  /**
   * @param {string} id
   * @param {any} [payload]
   * @param {string} [error]
   * @description To be called by Swift only
   */
  const __handleEvent__ = (id, payload, error = undefined) => {
    try {
      document.dispatchEvent(new CustomEvent(id, { detail: payload }));
      if (eventById[id]) {
        eventById[id](payload, error);
        delete eventById[id];
      }
    } catch (err) {
      console.error("[onboarding] __handleEvent__ error:", err);
    }
  };
  
  // Expose __handleEvent__ globally so Swift can call it
  window.__handleEvent__ = __handleEvent__;
  
  /**
   * @param {string} id
   * @param {string} action
   * @param {Object.<string, any> | undefined} [params={}]
   * @param {boolean} [replyRequierd=true]
   */
  const sendMessage = (id, action, params, replyRequierd) => {
    try {
      // Security: Validate payload size (max 1MB to prevent memory exhaustion)
      const messageSize = JSON.stringify({ id, action, params, replyRequierd }).length;
      if (messageSize > 1_048_576) { // 1MB limit
        console.error("[onboarding] sendMessage error: Payload too large:", messageSize, "bytes");
        return;
      }
      
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[swiftEndPoint]) {
        window.webkit.messageHandlers[swiftEndPoint].postMessage({
          id,
          action,
          params,
          replyRequierd,
        });
      } else {
        // Fallback for testing
        window.dispatchEvent(new CustomEvent("onboarding", { detail: { id, action, params, replyRequierd } }));
      }
    } catch (err) {
      console.error("[onboarding] sendMessage error:", err);
    }
  };
  
  /** @returns {string} */
  const uuid = () => {
    // Add timestamp to reduce collision risk (ultra-deep safety)
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(16).slice(2);
    return `${timestamp}_${random}`;
  };
  
  /**
   * Fire and forget - no response expected
   * @param {string} action
   * @param {Object.<string, any> | undefined} [params={}]
   */
  const call = (action, params = {}) => {
    sendMessage(uuid(), action, params, false);
  };
  
  /**
   * Fire and forget with action object
   * @param {{action: string, properties?: Object.<string, any>}} actionObj
   */
  const callAction = (actionObj) => {
    sendMessage(uuid(), actionObj.action, actionObj.properties || {}, false);
  };
  
  /**
   * Async call with Promise - expects response
   * @param {string} action
   * @param {Object.<string, any> | undefined} [params={}]
   * @param {number} [timeoutInSeconds]
   * @returns {Promise<any>}
   */
  const callAsync = async (action, params = {}, timeoutInSeconds = undefined) => {
    return new Promise((resolve, reject) => {
      /** @type {Callback} */
      const callback = (payload, error) => {
        if (error) {
          reject(new Error(error));
        } else {
          resolve(payload);
        }
      };
      
      /** @type {string} */
      const id = uuid();
      eventById[id] = callback;
      
      if (timeoutInSeconds) {
        setTimeout(() => {
          if (eventById[id]) {
            delete eventById[id];
            reject(new Error(`Timeout error, call exceeded ${timeoutInSeconds} seconds`));
          }
        }, timeoutInSeconds * 1000);
      }
      
      sendMessage(id, action, params, true);
    });
  };
  
  /**
   * Async call with action object
   * @param {{action: string, properties?: Object.<string, any>}} actionObj
   * @param {number} [timeoutInSeconds]
   * @returns {Promise<any>}
   */
  const callActionAsync = async (actionObj, timeoutInSeconds = undefined) => {
    return callAsync(actionObj.action, actionObj.properties || {}, timeoutInSeconds);
  };
  
  // Legacy function for backward compatibility - maps to new pattern
  function postToNative(type, payload) {
    // Send payload directly as params (not nested under 'payload' key)
    call(type, payload || {});
    return true;
  }

  // ============================================================================
  // ANALYTICS - Post Request Pattern
  // ============================================================================
  
  /**
   * Helper to create query param string
   */
  const createQueryParamString = (data) => {
    const params = [];
    for (const [key, value] of Object.entries(data)) {
      params.push(`${key}=${value}`);
    }
    return params.join("&");
  };

  /**
   * Send analytics event (matches company pattern)
   * @param {string} type - Event type
   * @param {string} [identifier] - Ad identifier
   * @param {boolean} [logAppsFlyer] - Whether to log to AppsFlyer
   * @param {string} [info] - Additional info
   * @param {Function} [cb] - Callback after request
   */
  const sendPostRequest = (type, identifier = "", logAppsFlyer = true, info = "", cb = () => {}) => {
    const data = {
      cid: CID,
      userId: USERID,
      installTime: INSTALL_TIME,
      event: type,
      source: "js",
      appName: "Calorie Counter AI",
      senderVersion: VERSION,
      appVersion: APP_VERSION,
      session_id: SESSION_ID,
      info: info,
    };
    if (identifier) {
      data["adIdentifier"] = identifier;
    }
    
    if (logAppsFlyer) {
      callActionAsync({ action: "appsFlyerEvent", properties: { name: type, values: data } }).then((res) => {
      }).catch((error) => {
        sendPostRequest("catchError_appsFlyerEvent", '', false, JSON.stringify(error));
      });
    }

    const params = createQueryParamString(data);
    const url = 'https://app.caloriecount-ai.com/pixel?' + params;

    fetch(url, {
      method: 'POST',
      body: JSON.stringify({}),
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    }).then(() => {
      cb();
    }).catch((error) => {
      const errorData = {
        eventType: type,
        error: JSON.stringify(error),
      };
      if (type !== "fetchError") {
        sendPostRequest("fetchError", '', false, JSON.stringify(errorData));
      }
      cb();
    });
  };

  // ---- Utilities ----
  function clamp(n, min, max) { return Math.min(max, Math.max(min, n)); }
  function fmtNumber(n, step) {
    const decimals = (String(step).split(".")[1] || "").length;
    return Number(n).toFixed(decimals);
  }

  function toCm(height, unit) {
    const v = Number(height);
    if (!Number.isFinite(v) || v <= 0) {
      return null;
    }
    return unit === "ft" ? v * 30.48 : v;
  }
  function toKg(weight, unit) {
    const v = Number(weight);
    if (!Number.isFinite(v) || v <= 0) {
      return null;
    }
    return unit === "lb" || unit === "lbs" ? v * 0.453592 : v;
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

  // ---- Native Permission Bridge ----
  // Allows the HTML onboarding flow to trigger *native* iOS permission prompts
  // and wait for the result before continuing.
  let __permSeq = 0;

  /** @param {string} status */
  function isPermissionGranted(status) {
    return (
      status === "authorized" ||
      status === "granted" ||
      status === "provisional" ||
      status === "ephemeral"
    );
  }

  /**
   * Ask native iOS for a permission status / request / open settings.
   * Uses callAsync pattern for reliable communication with Swift.
   *
   * @param {string} permissionType  e.g. 'notifications' | 'tracking'
   * @param {'status' | 'request' | 'open_settings' | 'decline'} action
   * @returns {Promise<{ok:boolean, requestId:string, permissionType:string, status:string, error?:string}>}
   */
  async function permissionViaNative(permissionType, action) {
    const requestId = `${permissionType}_${Date.now()}_${++__permSeq}`;
    
    try {
      // Use callAsync with the company pattern - expects response via __handleEvent__
      const response = await callAsync("permission_request", { 
        requestId, 
        permissionType, 
        action 
      }, 25); // 25 second timeout
      
      // Response should be { ok, requestId, permissionType, status, error? }
      return {
        ok: response?.ok ?? false,
        requestId: response?.requestId ?? requestId,
        permissionType: response?.permissionType ?? permissionType,
        status: response?.status ?? "unknown",
        error: response?.error
      };
    } catch (error) {
      // Timeout or other error
      console.error("[permissionViaNative] Error:", error);
      return {
        ok: false,
        requestId,
        permissionType,
        status: "timeout",
        error: error.message || "Failed to get permission status"
      };
    }
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
    const isWelcome = step.type === "welcome";
    const isPermission = step.type === "permission";

    // Hide topbar and progress for special screens
    const hideNav = isGenerating || isWelcome;
    topbar.classList.toggle("hidden", hideNav);
    progressWrap.classList.toggle("hidden", hideNav);

    const idx = order.indexOf(step.id);
    const total = order.length;
    const pct = Math.round((idx / (total - 1)) * 100);

    progressFill.style.width = `${clamp(pct, 0, 100)}%`;
    progressText.textContent = `${clamp(pct, 0, 100)}%`;
    progressSteps.textContent = `${idx + 1} / ${total}`;
    stepMeta.textContent = `Step ${idx + 1} of ${total}`;

    // Hide back button on first step (Step 1 requirement)
    const isFirstStep = state.stack.length === 0;
    if (backBtn) {
      backBtn.classList.toggle("hidden", isFirstStep);
      backBtn.disabled = isFirstStep;
    }
    
    if (skipBtn) {
      skipBtn.style.visibility = step.optional ? "visible" : "hidden";
    }

    content.innerHTML = "";
    footer.innerHTML = "";

    const wrap = document.createElement("div");
    // Apply transition animation based on navigation direction (Step 9)
    const animClass = state.navigationDirection === "back" ? "slideInLeft" : "slideInRight";
    wrap.className = animClass;

    if (step.type !== "goals_generation" && step.type !== "welcome" && step.type !== "permission") {
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
    } else if (step.type === "name_input") {
      wrap.appendChild(renderNameInput(step));
      renderFooterButtons(step, { showPrimary: true });
    } else if (step.type === "welcome") {
      wrap.appendChild(renderWelcome(step));
      renderFooterButtons(step, { showPrimary: true, primaryTitle: "Continue" });
    } else if (step.type === "permission") {
      wrap.appendChild(renderPermission(step));
      // Permission screens have their own buttons
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
      if (first && (step.type === "form" || step.type === "name_input")) first.focus({ preventScroll: true });
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
        // Step 6: Set default date to January 1, 2000
        if (field.input.defaultValue && !saved[field.id]) {
          input.value = field.input.defaultValue;
        }
      }

      // Load saved value - convert number to string for input.value
      const savedValue = saved[field.id];
      
      // Load saved value if it exists and is valid
      // For number fields, only load if it's a valid finite number
      // For other fields, load if it's not null/undefined/empty
      if (savedValue != null && savedValue !== "") {
        if (field.input.type === "number") {
          const numValue = Number(savedValue);
          // Only load if it's a valid finite number
          // Don't load obviously invalid values (NaN, Infinity, or extremely small/large values)
          if (Number.isFinite(numValue)) {
            input.value = String(savedValue);
          } else {
            input.value = "";
          }
        } else {
          input.value = String(savedValue);
        }
      } else if (field.input.type === "date" && field.input.defaultValue) {
        // Apply default value for date fields (Step 6)
        input.value = field.input.defaultValue;
      } else {
        input.value = "";
      }
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
      error.id = `error_${step.id}_${field.id}`;
      
      // Custom error messages
      if (field.id === "birthdate") {
        error.innerHTML = '<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg> <span class="errorText">Please enter your birthdate.</span>';
      } else {
        error.innerHTML = `<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg> <span class="errorText">Please enter your ${field.label.toLowerCase()}.</span>`;
      }

      const onChange = () => {
        const obj = state.answers[step.id] || {};
        // Convert to number if field type is number, otherwise keep as string
        const value = field.input.type === "number" ? Number(input.value) : input.value;
        obj[field.id] = value;
        if (unitSelect) obj[`${field.id}__unit`] = unitSelect.value;
        state.answers[step.id] = obj;
        
        // Step 7: Age validation for birthdate field
        if (field.id === "birthdate" && input.value) {
          const ageValid = validateAge(input.value, fieldEl);
          if (!ageValid) {
            // Keep field marked as invalid
          }
        } else {
          validateStep(step, { soft: true });
        }
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
      
      // Step 7: Add age restriction notice for birthdate
      if (field.id === "birthdate") {
        const ageNotice = document.createElement("div");
        ageNotice.className = "ageNotice";
        ageNotice.style.display = "none";
        ageNotice.id = "ageNotice";
        ageNotice.innerHTML = '<svg viewBox="0 0 24 24"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg> <span>You must be at least 13 years old to use this app.</span>';
        fieldEl.appendChild(ageNotice);
      }

      fieldEl.appendChild(error);
      fieldsWrap.appendChild(fieldEl);
    });

    return fieldsWrap;
  }

  // Step 7: Age validation function
  function validateAge(birthdateStr, fieldEl) {
    const age = calculateAge(birthdateStr);
    const ageNotice = document.getElementById("ageNotice");
    const errorEl = fieldEl.querySelector(".error");
    
    if (age < MIN_AGE) {
      fieldEl.classList.add("invalid");
      if (ageNotice) ageNotice.style.display = "flex";
      if (errorEl) {
        const errorText = errorEl.querySelector(".errorText");
        if (errorText) errorText.textContent = `You must be at least ${MIN_AGE} years old.`;
        errorEl.style.display = "flex";
      }
      return false;
    } else {
      fieldEl.classList.remove("invalid");
      if (ageNotice) ageNotice.style.display = "none";
      if (errorEl) errorEl.style.display = "none";
      return true;
    }
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
          // Don't auto-advance - user must click Continue button
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
        const optIcon = isObject ? opt.icon : null; // Step 8: Get icon

        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "opt";
        btn.setAttribute("role", "radio");
        btn.setAttribute("aria-checked", "false");

        // Step 8: Add icon if present
        if (optIcon) {
          const iconEl = document.createElement("div");
          iconEl.className = "optIcon";
          iconEl.textContent = optIcon;
          btn.appendChild(iconEl);
        }

        const left = document.createElement("div");
        left.className = "optContent";
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
          // Don't auto-advance - user must click Continue button
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

  // ---- Name Input Screen (Step 3) ----
  function renderNameInput(step) {
    const saved = state.answers[step.id] || {};
    const wrap = document.createElement("div");
    wrap.className = "fields";

    const fieldEl = document.createElement("div");
    fieldEl.className = "field";
    fieldEl.dataset.fieldId = "name";

    const labelRow = document.createElement("div");
    labelRow.className = "labelRow";

    const label = document.createElement("label");
    label.textContent = "Your Name";
    label.setAttribute("for", "in_name_input");

    const req = document.createElement("span");
    req.className = "req";
    req.textContent = "Required";

    labelRow.appendChild(label);
    labelRow.appendChild(req);

    const control = document.createElement("div");
    control.className = "control";

    const input = document.createElement("input");
    input.id = "in_name_input";
    input.type = "text";
    input.placeholder = "Enter your name";
    input.autocomplete = "given-name";
    input.autocapitalize = "words";
    input.value = saved.value || "";

    input.addEventListener("input", () => {
      state.answers[step.id] = { value: input.value.trim() };
      validateNameInput(fieldEl, input.value.trim());
      updatePrimaryEnabled(step);
    });

    control.appendChild(input);

    const error = document.createElement("div");
    error.className = "error";
    error.innerHTML = '<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg> Please enter at least 2 characters.';

    fieldEl.appendChild(labelRow);
    fieldEl.appendChild(control);
    fieldEl.appendChild(error);
    wrap.appendChild(fieldEl);

    // Initialize state
    state.answers[step.id] = { value: saved.value || "" };

    return wrap;
  }

  function validateNameInput(fieldEl, value) {
    const isValid = value.length >= 2;
    fieldEl.classList.toggle("invalid", !isValid && value.length > 0);
    return isValid;
  }

  // ---- Welcome Screen (Step 4) ----
  function renderWelcome(step) {
    const userName = state.answers["name_input"]?.value || "Friend";
    
    const wrap = document.createElement("div");
    wrap.className = "welcomeWrap scaleIn";

    const avatar = document.createElement("div");
    avatar.className = "welcomeAvatar";
    avatar.textContent = userName.charAt(0).toUpperCase();

    const title = document.createElement("h1");
    title.className = "welcomeTitle";
    title.textContent = `Welcome, ${userName}!`;

    const subtitle = document.createElement("p");
    subtitle.className = "welcomeSubtitle";
    subtitle.textContent = "We're excited to help you on your health journey. Let's set up your personalized plan.";

    wrap.appendChild(avatar);
    wrap.appendChild(title);
    wrap.appendChild(subtitle);

    return wrap;
  }

  // ---- Permission Screens (Steps 2 & 5) ----
  
  function renderPermission(step) {
    const wrap = document.createElement("div");
    wrap.className = "permissionWrap";

    const icon = document.createElement("div");
    icon.className = "permissionIcon floaty";
    icon.textContent = step.icon || "🔐";

    const title = document.createElement("h2");
    title.className = "permissionTitle";
    title.textContent = step.title;

    const desc = document.createElement("p");
    desc.className = "permissionDesc";
    desc.textContent = step.description;

    const statusPill = document.createElement("div");
    statusPill.className = "permissionStatusPill loading";
    statusPill.innerHTML = `<span class="spinner" aria-hidden="true"></span><span>Checking permission…</span>`;

    wrap.appendChild(icon);
    wrap.appendChild(title);
    wrap.appendChild(desc);
    wrap.appendChild(statusPill);

    if (step.benefits && step.benefits.length) {
      const benefitsWrap = document.createElement("div");
      benefitsWrap.className = "permissionBenefits";

      step.benefits.forEach((benefit, idx) => {
        const item = document.createElement("div");
        item.className = "benefitItem slideUp";
        item.style.animationDelay = `${0.05 + (idx * 0.05)}s`;

        const bIcon = document.createElement("div");
        bIcon.className = "benefitIcon";
        bIcon.textContent = benefit.icon;

        const bText = document.createElement("div");
        bText.className = "benefitText";
        bText.textContent = benefit.text;

        item.appendChild(bIcon);
        item.appendChild(bText);
        benefitsWrap.appendChild(item);
      });

      wrap.appendChild(benefitsWrap);
    }

    // Footer buttons (native permission request lives in Swift)
    footer.innerHTML = "";

    const primaryBtn = document.createElement("button");
    primaryBtn.className = "btn primary";
    primaryBtn.type = "button";

    const secondaryBtn = document.createElement("button");
    secondaryBtn.className = "btn ghost";
    secondaryBtn.type = "button";

    let currentStatus = "checking";
    let busy = false;

    function setBusy(isBusy) {
      busy = isBusy;
      primaryBtn.disabled = isBusy;
      secondaryBtn.disabled = isBusy;
      statusPill.classList.toggle("loading", isBusy);

      if (isBusy) {
        // Keep the spinner visible while the system dialog is up
        statusPill.innerHTML = `<span class="spinner" aria-hidden="true"></span><span>Waiting for iOS…</span>`;
      }
    }

    function setStatus(status) {
      currentStatus = status;

      statusPill.classList.remove("ok", "bad", "warn", "neutral", "loading");
      statusPill.classList.add("permissionStatusPill"); // ensure base

      const granted = isPermissionGranted(status);

      // Reset content + classes
      if (status === "checking") {
        statusPill.classList.add("loading");
        statusPill.innerHTML = `<span class="spinner" aria-hidden="true"></span><span>Checking permission…</span>`;
        return;
      }

      if (granted) {
        statusPill.classList.add("ok");
        statusPill.innerHTML = `<span class="dot okDot" aria-hidden="true"></span><span>Enabled</span>`;
        return;
      }

      if (status === "denied" || status === "restricted") {
        statusPill.classList.add("bad");
        statusPill.innerHTML = `<span class="dot badDot" aria-hidden="true"></span><span>Not enabled</span>`;
        return;
      }

      if (status === "not_determined") {
        statusPill.classList.add("neutral");
        statusPill.innerHTML = `<span class="dot neutralDot" aria-hidden="true"></span><span>Not requested yet</span>`;
        return;
      }

      if (status === "unavailable") {
        statusPill.classList.add("neutral");
        statusPill.innerHTML = `<span class="dot neutralDot" aria-hidden="true"></span><span>Preview mode</span>`;
        return;
      }

      statusPill.classList.add("neutral");
      statusPill.innerHTML = `<span class="dot neutralDot" aria-hidden="true"></span><span>Status: ${String(status || "unknown")}</span>`;
    }

    function persistAnswer(status, action) {
      const allowed = isPermissionGranted(status);
      state.permissions[step.permissionType] = allowed;
      state.answers[step.id] = { allowed, status, action };
    }

    function setButtonsForStatus(status) {
      footer.innerHTML = "";

      const granted = isPermissionGranted(status);

      if (granted) {
        primaryBtn.textContent = "Continue";
        primaryBtn.onclick = () => {
          persistAnswer(status, "continue");
          goNext();
        };
        footer.appendChild(primaryBtn);
        return;
      }

      if (status === "denied" || status === "restricted") {
        secondaryBtn.textContent = "Continue";
        secondaryBtn.onclick = () => {
          persistAnswer(status, "continue");
          goNext();
        };

        primaryBtn.textContent = "Open Settings";
        primaryBtn.onclick = async () => {
          setBusy(true);
          await permissionViaNative(step.permissionType, "open_settings");
          setBusy(false);
          // After returning from Settings, we can re-check status
          const res = await permissionViaNative(step.permissionType, "status");
          if (res && res.ok) {
            setStatus(res.status);
            setButtonsForStatus(res.status);
            persistAnswer(res.status, "status");
          }
        };

        footer.appendChild(secondaryBtn);
        footer.appendChild(primaryBtn);
        return;
      }

      // Not determined / unknown → show Allow + Not now
      secondaryBtn.textContent = "Not Now";
      secondaryBtn.onclick = () => {
        persistAnswer("skipped", "decline");
        call("permission_request", { permissionType: step.permissionType, action: "decline" });
        goNext();
      };

      primaryBtn.textContent =
        step.permissionType === "notifications" ? "Enable Notifications" : "Allow Tracking";

      primaryBtn.onclick = async () => {
        setBusy(true);
        const res = await permissionViaNative(step.permissionType, "request");
        setBusy(false);

        const status = res && res.ok ? res.status : "unknown";
        setStatus(status);
        setButtonsForStatus(status);
        persistAnswer(status, "request");

        // If the user granted permission, keep the flow snappy and continue automatically.
        if (isPermissionGranted(status)) {
          // DISABLED AUTO-ADVANCE: User should manually click Continue after permission is granted
          // setTimeout(() => goNext(), 420);
        }
      };

      footer.appendChild(secondaryBtn);
      footer.appendChild(primaryBtn);
    }

    // Initial status check and auto-request permission if not determined
    (async () => {
      const res = await permissionViaNative(step.permissionType, "status");
      const status = res && res.ok ? res.status : "not_determined";
      setStatus(status);
      
      // If permission is not determined, automatically request it (show native prompt)
      if (status === "not_determined") {
        setBusy(true);
        const requestRes = await permissionViaNative(step.permissionType, "request");
        setBusy(false);
        
        const finalStatus = requestRes && requestRes.ok ? requestRes.status : status;
        setStatus(finalStatus);
        setButtonsForStatus(finalStatus);
        persistAnswer(finalStatus, "request");
        
        // If the user granted permission, keep the flow snappy and continue automatically.
        if (isPermissionGranted(finalStatus)) {
          // DISABLED AUTO-ADVANCE: User should manually click Continue after permission is granted
          // setTimeout(() => goNext(), 420);
        }
      } else {
        setButtonsForStatus(status);
        persistAnswer(status, "status");
      }
    })();

    return wrap;
  }


  // ---- Landing Pages (Steps 11 & 12) ----
  function renderLanding(step) {
    const wrap = document.createElement("div");
    wrap.className = "landingWrap";

    if (step.landingType === "comparison") {
      // App comparison chart (Step 12)
      const icon = document.createElement("div");
      icon.className = "landingIcon";
      icon.textContent = "🏆";

      const title = document.createElement("h1");
      title.className = "landingTitle";
      title.textContent = step.title;

      const desc = document.createElement("p");
      desc.className = "landingDesc";
      desc.textContent = step.description;

      wrap.appendChild(icon);
      wrap.appendChild(title);
      wrap.appendChild(desc);

      // Comparison chart
      const chart = document.createElement("div");
      chart.className = "comparisonChart";

      // Our App - 90%
      const ourApp = document.createElement("div");
      ourApp.className = "comparisonItem";
      ourApp.innerHTML = `
        <div class="comparisonHeader">
          <div class="comparisonLabel ourApp">
            <div class="appIcon">✓</div>
            <span>Our App</span>
          </div>
          <span class="comparisonValue" style="color: var(--accent2);">90%</span>
        </div>
        <div class="comparisonTrack">
          <div class="comparisonFill ourApp" data-width="90"></div>
        </div>
      `;

      // Other Apps - 50%
      const otherApps = document.createElement("div");
      otherApps.className = "comparisonItem";
      otherApps.innerHTML = `
        <div class="comparisonHeader">
          <div class="comparisonLabel otherApps">
            <div class="appIcon">○</div>
            <span>Other Apps</span>
          </div>
          <span class="comparisonValue" style="color: var(--muted);">50%</span>
        </div>
        <div class="comparisonTrack">
          <div class="comparisonFill otherApps" data-width="50"></div>
        </div>
      `;

      chart.appendChild(ourApp);
      chart.appendChild(otherApps);
      wrap.appendChild(chart);

      // Animate bars after render (Step 10)
      setTimeout(() => {
        const fills = chart.querySelectorAll(".comparisonFill");
        fills.forEach((fill) => {
          const width = fill.getAttribute("data-width");
          fill.style.width = `${width}%`;
        });
      }, 100);

    } else if (step.landingType === "stats") {
      // Stats grid (Step 11)
      const icon = document.createElement("div");
      icon.className = "landingIcon";
      icon.textContent = "📊";

      const title = document.createElement("h1");
      title.className = "landingTitle";
      title.textContent = step.title;

      const desc = document.createElement("p");
      desc.className = "landingDesc";
      desc.textContent = step.description;

      wrap.appendChild(icon);
      wrap.appendChild(title);
      wrap.appendChild(desc);

      // Stats grid
      const grid = document.createElement("div");
      grid.className = "statsGrid";

      if (step.stats) {
        step.stats.forEach((stat, idx) => {
          const card = document.createElement("div");
          card.className = "statCard slideUp";
          card.style.animationDelay = `${idx * 0.1}s`;
          card.innerHTML = `
            <div class="statValue">${stat.value}</div>
            <div class="statLabel">${stat.label}</div>
          `;
          grid.appendChild(card);
        });
      }

      wrap.appendChild(grid);
    }

    return wrap;
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

    // Ensure interval is always cleared, even on unexpected errors
    (async () => {
      try {
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
          call("goals_generated", { ok: true, goals: state.generatedGoals });
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

          call("goals_generated", { ok: true, goals: state.generatedGoals });
        } catch (err) {
          clearInterval(msgInterval);
          const msg = (err && err.name === "AbortError")
            ? "Request timed out. Please try again."
            : (err && err.message) ? err.message : "Something went wrong.";
          console.warn("[Goals API error]", err);
          call("goals_generated", { ok: false, error: msg });
          showGoalsError(msg, `${getApiBaseUrl()}/calories/goals`);
        }
      } catch (unexpectedError) {
        // Safety net: clear interval on any unexpected error
        clearInterval(msgInterval);
        console.error("❌ [startGoalsGeneration] Unexpected error:", unexpectedError);
        const msg = unexpectedError.message || "An unexpected error occurred";
        call("goals_generated", { ok: false, error: msg });
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

  // Render button to finish onboarding (no more landing pages)
  const step = byId.get("generating");
  renderFooterButtons(step, { showPrimary: true, primaryTitle: "Get Started" });
}

function calculateDefaultGoals() {
    const a = state.answers;
    const gender = (a.gender?.value || "male").toLowerCase();
    
    // Get normalized height/weight if available, otherwise calculate
    let weight = a._normalized?.weight_kg;
    let height = a._normalized?.height_cm;

    if (!weight || !height) {
         // Fallback if _normalized is missing
         const hw = a.height_weight || {};
         weight = toKg(hw.weight, hw.weight__unit || "kg") || 70;
         height = toCm(hw.height, hw.height__unit || "cm") || 170;
    }

    const birthdate = a.birthdate?.birthdate;
    const age = birthdate ? calculateAge(birthdate) : 30;

    // BMR (Mifflin-St Jeor)
    let bmr = (10 * weight) + (6.25 * height) - (5 * age);
    if (gender === "male") {
        bmr += 5;
    } else {
        bmr -= 161;
    }

    // TDEE - Activity Multipliers
    const activityMap = {
        "sedentary": 1.2,
        "lightly_active": 1.375,
        "moderately_active": 1.55,
        "very_active": 1.725,
        "extra_active": 1.9
    };
    const activity = a.activity_level?.value || "moderately_active";
    const multiplier = activityMap[activity] || 1.375;
    const tdee = bmr * multiplier;

    // Goal Adjustment
    const goal = a.goal?.value || "maintain";
    let adjustment = 0;
    if (goal === "lose_weight") adjustment = -500;
    else if (goal === "gain_weight") adjustment = 500;
    
    // Total Calories
    // Ensure we don't go below 1200 as a safety floor
    let dailyCalories = Math.round(tdee + adjustment);
    if (dailyCalories < 1200) dailyCalories = 1200;

    // Macros (30% Protein, 40% Carbs, 30% Fat)
    const proteinCals = dailyCalories * 0.30;
    const carbsCals = dailyCalories * 0.40;
    const fatCals = dailyCalories * 0.30;

    const proteinG = Math.round(proteinCals / 4);
    const carbsG = Math.round(carbsCals / 4);
    const fatG = Math.round(fatCals / 9);

    return {
        daily_calories: dailyCalories,
        macros: {
            protein_g: proteinG,
            carbs_g: carbsG,
            fat_g: fatG,
            fiber_g: 30
        },
        // Flattened structure for UI
        calories: dailyCalories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        
        // Metadata
        bmi: weight / ((height/100) * (height/100)),
        bmr: bmr,
        tdee: tdee,
        calorie_adjustment: adjustment,
        isDefault: true
    };
}

function showGoalsError(message, apiUrl) {
  const loadingEl = document.getElementById("goalsLoading");
  const resultsEl = document.getElementById("goalsResults");

  if (loadingEl) loadingEl.style.display = "none";
  if (!resultsEl) return;

  resultsEl.style.display = "block";
  resultsEl.innerHTML = `
    <div class="successCheck" style="background: linear-gradient(135deg, rgba(255,90,122,.18), rgba(255,90,122,.08)); margin: 0 auto;">!</div>
    <h1 style="margin-top:16px;">Something went wrong</h1>
    <p class="desc" style="margin-bottom:12px;">We couldn't connect to our servers.</p>
  `;

  footer.innerHTML = "";
  
  // Container for stacked buttons
  const btnGroup = document.createElement("div");
  btnGroup.style.display = "flex";
  btnGroup.style.flexDirection = "column";
  btnGroup.style.width = "100%";
  btnGroup.style.gap = "12px";

  // Try Again Button
  const retry = document.createElement("button");
  retry.className = "btn primary";
  retry.type = "button";
  retry.textContent = "Try Again";
  retry.addEventListener("click", () => {
    state.currentId = "generating";
    render();
  });

  // Continue Anyway Button
  const cont = document.createElement("button");
  cont.className = "btn ghost";
  cont.type = "button";
  cont.textContent = "Continue Anyway";
  cont.addEventListener("click", () => {
    const defaultGoals = calculateDefaultGoals();
    state.generatedGoals = defaultGoals;
    showGoalsResults(defaultGoals);
    
    // Notify native
    call("goals_generated", { ok: true, goals: defaultGoals, isDefault: true });
  });

  btnGroup.appendChild(retry);
  btnGroup.appendChild(cont);
  footer.appendChild(btnGroup);
}

  function renderFooterButtons(step, { showPrimary, primaryTitle } = {}) {
    footer.innerHTML = "";
    
    const primary = document.createElement("button");
    primary.className = "btn primary";
    primary.type = "button";

    primary.textContent = primaryTitle || (step.next ? "Continue" : "Get Started");
    primary.addEventListener("click", () => {
      if (step.type === "goals_generation") {
        // After goals generation, finish onboarding (no more landing pages)
        finish();
        return;
      }
      if (step.type === "name_input") {
        const nameValue = state.answers[step.id]?.value || "";
        if (nameValue.length < 2) {
          const fieldEl = content.querySelector('.field[data-field-id="name"]');
          if (fieldEl) fieldEl.classList.add("invalid");
          return;
        }
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
      let val = (saved[field.id] ?? "").toString().trim();

      // If saved value is empty, check the actual input field value (for default values)
      if (val.length === 0 && fieldEl) {
        const input = fieldEl.querySelector(`input[type="${field.input.type}"]`);
        if (input && input.value) {
          val = input.value.trim();
        }
      }

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
        
        // Step 7: Age validation
        if (field.id === "birthdate" && !invalid) {
          const age = calculateAge(val);
          if (age < MIN_AGE) {
            invalid = true;
          }
        }
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
    } else if (step.type === "name_input") {
      // Step 3: Name requires at least 2 characters
      const a = state.answers[step.id];
      enabled = !!(a && a.value && a.value.trim().length >= 2);
    } else if (step.type === "welcome") {
      enabled = true;
    } else if (step.type === "permission") {
      // Permission screens have their own buttons
      enabled = true;
    }

    primary.disabled = !enabled;
  }

  // ---- Navigation ----
  function goTo(stepId) {
    const step = byId.get(stepId);
    if (!step) return;
    state.currentId = stepId;
    
    // Mark onboarding as completed when reaching the generating/paywall step
    // This means user has answered all questions
    if (stepId === "generating") {
      setOnboardingCompleted();
      saveAnswersToStorage();
    }
    
    render();
    call("step_view", { stepId });
    sendPostRequest("step_" + stepId, '', false);
  }

  function goNext() {
    const step = byId.get(state.currentId);
    if (!step) return;

    // Set navigation direction for animation (Step 9)
    state.navigationDirection = "forward";

    if (!step.next) {
      finish();
      return;
    }

    // For form steps, explicitly save all field values before proceeding
    // This ensures values are saved even if onChange wasn't triggered
    if (step.type === "form") {
      const obj = state.answers[step.id] || {};
      step.fields.forEach((field) => {
        const input = content.querySelector(`#in_${step.id}_${field.id}`);
        if (input) {
          const rawValue = input.value.trim();
          
          // For date fields with default values, always save the value (even if it's the default)
          // For other fields, only save if the input has a non-empty value
          const shouldSave = (rawValue && rawValue !== "") || 
                            (field.input.type === "date" && field.input.defaultValue && rawValue === field.input.defaultValue);
          
          if (shouldSave) {
            // Convert to number if field type is number, otherwise keep as string
            const value = field.input.type === "number" ? Number(rawValue) : rawValue;
            
            // Only save if the value is valid (not NaN for numbers, not empty for strings)
            if (field.input.type === "number") {
              // For number fields, validate that it's a finite number
              // Note: We allow 0 for some fields (like age could theoretically be 0 for newborns)
              // But for height/weight, we validate > 0 in the normalization step
              if (Number.isFinite(value)) {
                obj[field.id] = value;
              }
            } else {
              // For non-number fields (including date), save the trimmed value
              obj[field.id] = value;
            }
            
            // Save unit if field has unit options
            const unitSelect = input.parentElement?.querySelector("select");
            if (unitSelect) {
              obj[`${field.id}__unit`] = unitSelect.value;
            }
          }
        }
      });
      state.answers[step.id] = obj;
    }

    // For name_input step, validate before proceeding
    if (step.type === "name_input") {
      const nameValue = state.answers[step.id]?.value || "";
      if (nameValue.length < 2) {
        const fieldEl = content.querySelector('.field[data-field-id="name"]');
        if (fieldEl) fieldEl.classList.add("invalid");
        return;
      }
    }

    state.stack.push(step.id);

    if (step.id === "height_weight") {
      const a = state.answers[step.id] || {};
      
      // Get height and weight values - check both saved answers and input fields
      let h = a.height;
      let hu = a["height__unit"];
      let w = a.weight;
      let wu = a["weight__unit"];
      
      // Fallback: Try to get values directly from input fields if saved values are missing
      // This handles edge cases where values weren't saved properly in the form step above
      if (!h || !w) {
        const heightInput = content.querySelector(`#in_${step.id}_height`);
        const weightInput = content.querySelector(`#in_${step.id}_weight`);
        
        if (!h && heightInput && heightInput.value) {
          const trimmedHeight = heightInput.value.trim();
          if (trimmedHeight !== "") {
            const heightValue = Number(trimmedHeight);
            if (Number.isFinite(heightValue) && heightValue > 0) {
              h = heightValue;
            }
          }
        }
        
        if (!w && weightInput && weightInput.value) {
          const trimmedWeight = weightInput.value.trim();
          if (trimmedWeight !== "") {
            const weightValue = Number(trimmedWeight);
            if (Number.isFinite(weightValue) && weightValue > 0) {
              w = weightValue;
            }
          }
        }
        
        // Get units from selects if not already saved
        if (!hu && heightInput) {
          const heightUnitSelect = heightInput.parentElement?.querySelector("select");
          if (heightUnitSelect && heightUnitSelect.value) {
            hu = heightUnitSelect.value;
          }
        }
        
        if (!wu && weightInput) {
          const weightUnitSelect = weightInput.parentElement?.querySelector("select");
          if (weightUnitSelect && weightUnitSelect.value) {
            wu = weightUnitSelect.value;
          }
        }
      }
      
      // Convert to numbers and set defaults
      const hNum = Number(h) || 0;
      const wNum = Number(w) || 0;
      const huFinal = hu || "cm";
      const wuFinal = wu || "kg";
      
      // Only normalize if we have valid values
      if (hNum > 0 && wNum > 0) {
        const cm = toCm(hNum, huFinal);
        const kg = toKg(wNum, wuFinal);
        
        if (cm && kg) {
          state.answers._normalized = state.answers._normalized || {};
          state.answers._normalized.height_cm = cm;
          state.answers._normalized.weight_kg = kg;
        }
      }
    }

    goTo(step.next);
  }

  function goBack() {
    const prev = state.stack.pop();
    if (!prev) return;
    // Set navigation direction for animation (Step 9)
    state.navigationDirection = "back";
    goTo(prev);
  }

  function finish() {
    const payload = {
      answers: state.answers,
      goals: state.generatedGoals,
      permissions: state.permissions,
      userName: state.answers["name_input"]?.value || null,
      completedAt: new Date().toISOString(),
    };

    call("complete", payload);
    sendPostRequest("onboarding_complete", '', true, JSON.stringify(payload), () => {
      callAction({ action: "dismiss" });
    });

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
  // Event listeners will be set up in initializeOnboarding() after DOM is ready

  // ============================================================================
  // PUBLIC API - Expose functions globally
  // ============================================================================
  
  window.OnboardingWeb = {
    getState: () => JSON.parse(JSON.stringify(state)),
    setAnswers: (answersObj) => { state.answers = answersObj || {}; render(); },
    goTo: (stepId) => goTo(stepId),
    finish: () => finish(),
    start: (installTime = '') => {
      if (installTime !== '') {
        INSTALL_TIME = installTime;
      }
      // Check if user has completed onboarding before
      const alreadyCompleted = hasCompletedOnboarding();
      sendPostRequest("onboarding_check", '', false, alreadyCompleted ? "returning_user" : "first_time_user");
      
      if (alreadyCompleted) {
        // Returning user - skip directly to paywall/generating
        skipToPaywall();
      } else {
        // First time user - show full onboarding
        render();
        call("ready", { firstStepId: state.currentId });
      }
      
      // Track time spent
      setInterval(() => {
        SECONDS++;
      }, 1000);
    },
    resetOnboarding: () => {
      try {
        localStorage.removeItem(ONBOARDING_COMPLETED_KEY);
        localStorage.removeItem('caloriecount_onboarding_answers');
        sendPostRequest("onboarding_reset", '', false);
      } catch (e) {}
    }
  };

  // TEMPORARY FIX: Legacy global exports to support older native bridge calls
  // Some native code still calls start(...) directly or reads SESSION_ID globally.
  // TODO: Remove when onboarding is migrated to SDK (like paywall) - SDK will handle this
  window.start = window.OnboardingWeb.start;
  window.SESSION_ID = SESSION_ID;
  window.USERID = USERID;
  window.CID = CID;
  window.APP_VERSION = APP_VERSION;
  
  // Expose bridge functions for debugging
  window.OnboardingBridge = {
    call,
    callAsync,
    callAction,
    callActionAsync,
    __handleEvent__,
  };

  // TEMPORARY FIX: If native called start() before onboarding.js loaded, replay it now
  // TODO: Remove when onboarding is migrated to SDK - SDK will handle race conditions
  if (window.__pendingOnboardingStartArgs) {
    try {
      window.OnboardingWeb.start.apply(null, window.__pendingOnboardingStartArgs);
    } finally {
      window.__pendingOnboardingStartArgs = null;
    }
  }

  // ============================================================================
  // INIT - Auto-start if DOM is ready
  // ============================================================================
  
  function initializeOnboarding() {
    // Re-get DOM elements to ensure they exist
    const backBtnEl = document.getElementById("backBtn");
    const skipBtnEl = document.getElementById("skipBtn");
    
    // Set up event listeners if elements exist
    if (backBtnEl) {
      backBtnEl.addEventListener("click", goBack);
    }
    
    if (skipBtnEl) {
      skipBtnEl.addEventListener("click", () => {
        const step = byId.get(state.currentId);
        if (step && step.optional) {
          delete state.answers[step.id];
          goNext();
        }
      });
    }
    
    // Render the initial step
    render();
    call("ready", { firstStepId: state.currentId });
    sendPostRequest("JSLoaded", "", false);
    sendPostRequest("initAppReady", "", false);
  }
  
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeOnboarding);
  } else {
    // DOM is already ready
    initializeOnboarding();
  }
})();
