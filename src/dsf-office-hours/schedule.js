const ScheduleUtils = {
  DATETIME_FORMAT: "EEEE, MMMM d 'at' h:mm a ZZZZ",
  WEEKDAY: 3, // wednesday
  TIME_OF_DAY: { hour: 18, minute: 0, second: 0, millisecond: 0 }, // 6pm

  getNextOfficeHours() {
    const DateTime = luxon.DateTime;
    let now = DateTime.now().setZone("UTC");
    let nextSession = now.set(this.TIME_OF_DAY);

    while (nextSession.weekday !== this.WEEKDAY) {
      nextSession = nextSession.plus({ days: 1 });
    }

    // If today is the session day and it's past time, move to next week
    if (now.weekday === this.WEEKDAY && now.hour >= this.TIME_OF_DAY.hour) {
      nextSession = nextSession.plus({ weeks: 1 });
    }

    return nextSession;
  },

  // Display the next office hours date
  init() {
    const DateTime = luxon.DateTime;
    const nextSession = this.getNextOfficeHours();

    // Format and display the date
    document.getElementById("next-session-utc").textContent = nextSession.toFormat(this.DATETIME_FORMAT);

    // Display local time
    const localTime = nextSession.setZone(DateTime.local().zoneName);
    document.getElementById("next-session-localtime").textContent = localTime.toFormat(this.DATETIME_FORMAT);
    document.getElementById("timezone-info").textContent = localTime.toFormat("ZZZZZ");
  },
};
