function tripPlanner() {
  return {
    savedTitle: null,     // name currently persisted in tripPlans
    editingTitle: '',     // value in the name input
    isEditingTitle: false, // true when in rename mode

    defaultLegs: [
      { title: "", method: "hike", distance: 3.5, elevationGain: 750 },
      { title: "", method: "float", distance: 2.0, elevationGain: 0 },
      { title: "", method: "bushwhack", distance: 1.2, elevationGain: 500 },
    ],
    defaultTravelMethods: [
      { name: "hike", minutesPerMile: 20, minutesPer1000ft: 30 },
      { name: "float", minutesPerMile: 15, minutesPer1000ft: 0 },
      { name: "bushwhack", minutesPerMile: 40, minutesPer1000ft: 60 },
    ],
    legs: [],
    travelMethods: [],
    savedTripsList: [],
    dailyMaxMiles: '',
    dailyMaxGain: '',

    // ── Name management ───────────────────────────────────────────────

    saveName() {
      const name = this.editingTitle.trim();
      if (!name) return;

      const plans = JSON.parse(localStorage.getItem("tripPlans") || "{}");

      // If renaming, remove the old entry
      if (this.savedTitle && this.savedTitle !== name) {
        delete plans[this.savedTitle];
      }

      plans[name] = { legs: this.legs, travelMethods: this.travelMethods, dailyMaxMiles: this.dailyMaxMiles, dailyMaxGain: this.dailyMaxGain };
      localStorage.setItem("tripPlans", JSON.stringify(plans));
      this.savedTripsList = Object.keys(plans);
      this.savedTitle = name;
      this.isEditingTitle = false;
      this.saveSessionState();
    },

    startRename() {
      this.editingTitle = this.savedTitle;
      this.isEditingTitle = true;
      this.$nextTick(() => this.$refs.nameInput.focus());
    },

    cancelRename() {
      this.editingTitle = this.savedTitle;
      this.isEditingTitle = false;
    },

    // ── Trip data persistence ─────────────────────────────────────────

    saveTrip() {
      this.saveSessionState();
      if (!this.savedTitle) return;
      const plans = JSON.parse(localStorage.getItem("tripPlans") || "{}");
      plans[this.savedTitle] = { legs: this.legs, travelMethods: this.travelMethods, dailyMaxMiles: this.dailyMaxMiles, dailyMaxGain: this.dailyMaxGain };
      localStorage.setItem("tripPlans", JSON.stringify(plans));
    },

    saveSessionState() {
      localStorage.setItem("savedTrip", JSON.stringify({
        savedTitle: this.savedTitle,
        editingTitle: this.editingTitle,
        legs: this.legs,
        travelMethods: this.travelMethods,
        dailyMaxMiles: this.dailyMaxMiles,
        dailyMaxGain: this.dailyMaxGain,
      }));
    },

    loadNamedTrip(name) {
      const plans = JSON.parse(localStorage.getItem("tripPlans") || "{}");
      const trip = plans[name];
      if (!trip) return;
      this.savedTitle = name;
      this.editingTitle = name;
      this.isEditingTitle = false;
      this.legs = trip.legs;
      this.travelMethods = trip.travelMethods;
      this.dailyMaxMiles = trip.dailyMaxMiles || '';
      this.dailyMaxGain = trip.dailyMaxGain || '';
      this.saveSessionState();
    },

    deleteNamedTrip(name) {
      if (!confirm(`Delete "${name}"?`)) return;
      const plans = JSON.parse(localStorage.getItem("tripPlans") || "{}");
      delete plans[name];
      localStorage.setItem("tripPlans", JSON.stringify(plans));
      this.savedTripsList = Object.keys(plans);
      if (this.savedTitle === name) {
        this.savedTitle = null;
        this.editingTitle = '';
        this.saveSessionState();
      }
    },

    // ── Leg / method mutations ────────────────────────────────────────

    addLeg() {
      const defaultMethod = this.travelMethods.length > 0 ? this.travelMethods[0].name : "";
      this.legs.push({ title: "", method: defaultMethod, distance: 0, elevationGain: 0 });
      this.saveTrip();
    },

    removeLeg(index) {
      this.legs.splice(index, 1);
      this.saveTrip();
    },

    addMethod() {
      const name = prompt("name");
      if (!name) return;
      this.travelMethods.push({ name, minutesPerMile: 20, minutesPer1000ft: 30 });
      this.saveTrip();
    },

    removeMethod(index) {
      if (this.travelMethods.length <= 1) return;
      const removedMethod = this.travelMethods[index].name;
      this.travelMethods.splice(index, 1);
      this.legs.forEach((leg) => {
        if (leg.method === removedMethod) leg.method = this.travelMethods[0].name;
      });
      this.saveTrip();
    },

    // ── Computed totals ───────────────────────────────────────────────

    get totalDistance() {
      return this.legs.reduce((sum, leg) => sum + parseFloat(leg.distance || 0), 0);
    },

    get totalElevationGain() {
      return this.legs.reduce((sum, leg) => sum + parseInt(leg.elevationGain || 0), 0);
    },

    get methodBreakdown() {
      const methods = {};
      this.legs.forEach((leg) => {
        if (!methods[leg.method]) methods[leg.method] = 0;
        methods[leg.method] += parseFloat(leg.distance || 0);
      });
      return Object.entries(methods)
        .map(([method, distance]) => `${distance.toFixed(1)} ${method.toLowerCase()}`)
        .join(", ");
    },

    calculateLegTime(leg) {
      const method = this.travelMethods.find((m) => m.name === leg.method);
      if (!method) return 0;
      const distanceTime = parseFloat(leg.distance || 0) * parseFloat(method.minutesPerMile || 0);
      const elevationTime = (parseFloat(leg.elevationGain || 0) / 1000) * parseFloat(method.minutesPer1000ft || 0);
      return (distanceTime + elevationTime) / 60;
    },

    get totalTime() {
      return this.legs.reduce((sum, leg) => sum + this.calculateLegTime(leg), 0);
    },

    legLabel(leg, index) {
      if (leg.title && leg.title.trim()) return leg.title.trim();
      const method = leg.method.charAt(0).toUpperCase() + leg.method.slice(1);
      return `${method} ${index + 1}`;
    },

    get dayPlan() {
      const maxMiles = parseFloat(this.dailyMaxMiles);
      const maxGain = parseFloat(this.dailyMaxGain);
      if (!maxMiles || !maxGain) return { days: [], camps: [] };

      const days = [];
      const camps = [];
      const freshDay = () => ({ legs: [], milesPerMethod: {}, gain: 0, time: 0 });
      let current = freshDay();
      let dayMiles = 0;
      let dayGain = 0;
      let legIndex = 0;
      let legOffset = 0;

      const accumulate = (leg, miles, gain) => {
        const method = this.travelMethods.find(m => m.name === leg.method);
        const mpm = method ? parseFloat(method.minutesPerMile || 0) : 0;
        const mp1k = method ? parseFloat(method.minutesPer1000ft || 0) : 0;
        if (!current.milesPerMethod[leg.method]) current.milesPerMethod[leg.method] = 0;
        current.milesPerMethod[leg.method] += miles;
        current.gain += gain;
        current.time += (miles * mpm + (gain / 1000) * mp1k) / 60;
      };

      while (legIndex < this.legs.length) {
        const leg = this.legs[legIndex];
        const totalLegMiles = parseFloat(leg.distance || 0);
        const totalLegGain = parseFloat(leg.elevationGain || 0);
        const remainingLegMiles = Math.max(0, totalLegMiles - legOffset);
        const gainRate = totalLegMiles > 0 ? totalLegGain / totalLegMiles : 0;
        const remainingLegGain = remainingLegMiles * gainRate;

        if (remainingLegMiles <= 0) {
          current.legs.push(this.legLabel(leg, legIndex));
          legIndex++;
          legOffset = 0;
          continue;
        }

        const milesBudget = maxMiles - dayMiles;
        const gainBudget = maxGain - dayGain;

        if (remainingLegMiles <= milesBudget + 1e-9 && remainingLegGain <= gainBudget + 1e-9) {
          current.legs.push(this.legLabel(leg, legIndex));
          accumulate(leg, remainingLegMiles, remainingLegGain);
          dayMiles += remainingLegMiles;
          dayGain += remainingLegGain;
          legIndex++;
          legOffset = 0;
        } else {
          let milesWeCanDo = milesBudget;
          if (gainRate > 0) milesWeCanDo = Math.min(milesWeCanDo, gainBudget / gainRate);
          milesWeCanDo = Math.min(Math.max(milesWeCanDo, 0), remainingLegMiles);

          const campOffset = legOffset + milesWeCanDo;
          current.legs.push(this.legLabel(leg, legIndex));
          accumulate(leg, milesWeCanDo, milesWeCanDo * gainRate);
          days.push({ ...current, milesPerMethod: { ...current.milesPerMethod } });

          if (Math.abs(campOffset - totalLegMiles) < 1e-9) {
            camps.push(`after ${this.legLabel(leg, legIndex)}`);
            legIndex++;
            legOffset = 0;
          } else {
            camps.push(`${campOffset.toFixed(1)} miles into ${this.legLabel(leg, legIndex)}`);
            legOffset = campOffset;
          }

          current = freshDay();
          dayMiles = 0;
          dayGain = 0;
        }
      }

      if (current.legs.length > 0) days.push({ ...current, milesPerMethod: { ...current.milesPerMethod } });
      return { days, camps };
    },

    get dayPlanRows() {
      const { days, camps } = this.dayPlan;
      const rows = [];
      days.forEach((day, i) => {
        const methodParts = Object.entries(day.milesPerMethod)
          .map(([method, miles]) => `${miles.toFixed(1)} ${method}`)
          .join(', ');
        const summary = [methodParts, `${Math.round(day.gain)} gain`, `${day.time.toFixed(1)} hrs`]
          .filter(Boolean).join(', ');
        rows.push({ type: 'day', n: i + 1, summary, legs: day.legs.join(', ') });
        if (i < camps.length) {
          rows.push({ type: 'camp', n: i + 1, text: `⛺ Camp ${i + 1}: ${camps[i]}` });
        }
      });
      return rows;
    },

    // ── Reset ─────────────────────────────────────────────────────────

    clearTrip() {
      if (!this.savedTitle && !confirm("Are you sure you want to clear all trip data?")) return;
      this.savedTitle = null;
      this.editingTitle = '';
      this.isEditingTitle = false;
      this.legs = [...this.defaultLegs];
      this.travelMethods = [...this.defaultTravelMethods];
      this.dailyMaxMiles = '';
      this.dailyMaxGain = '';
      localStorage.removeItem("savedTrip");
    },

    // ── Init ──────────────────────────────────────────────────────────

    init() {
      const savedTrip = localStorage.getItem("savedTrip");
      if (savedTrip) {
        const data = JSON.parse(savedTrip);
        this.savedTitle = data.savedTitle || null;
        this.editingTitle = data.editingTitle || '';
        if (data.travelMethods) this.travelMethods = data.travelMethods;
        if (data.legs) this.legs = data.legs;
        this.dailyMaxMiles = data.dailyMaxMiles || '';
        this.dailyMaxGain = data.dailyMaxGain || '';
      } else {
        this.legs = [...this.defaultLegs];
        this.travelMethods = [...this.defaultTravelMethods];
      }
      this.savedTripsList = Object.keys(JSON.parse(localStorage.getItem("tripPlans") || "{}"));
    },
  };
}
