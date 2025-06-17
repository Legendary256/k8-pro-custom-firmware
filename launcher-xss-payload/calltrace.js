// Inject this script to trace navigator.hid calls on the site. Useful for reversing

const outputCallTrace = (name, args) => {
  const m1 = `╭┈┈`;
  const m2 = `│ —> `;
  const m3 = `╰┈┈\n`;

  const callMessage = `${m2}call: HIDDevice.${name}(`;
  console.log(m1);
  console.log(callMessage, args, ')');
  console.log(m3);
}

const oninputreport = [];

var hiddev = {};

const mockedKbCalls =
{
  open: async (...args) => {
    outputCallTrace('open', args);
  },
  close: async (...args) => {
    outputCallTrace('close', args);
  },
  sendReport: async (...args) => {
    outputCallTrace('sendReport', args);
    debugger;
    console.log(oninputreport);
    oninputreport.forEach(cb => cb({
      data: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      reportId: 0,
      device: hiddev,
    }));
  },
  // Simulate event triggering
  dispatchEvent: async (...args) => {
    outputCallTrace('dispatchEvent', args);
  },
  addEventListener: async (event, fn, ...args) => {
    outputCallTrace('addEventListener', [event, fn, ...args]);
    oninputreport.push(fn);
  },
  removeEventListener: async (event, fn, ...args) => {
    outputCallTrace('removeEventListener', [event, fn, ...args]);
    oninputreport.splice(oninputreport.indexOf(fn));
  },
};

hiddev = {
  productName: "Mock HID Device",
  vendorId: 0x3434,
  productId: 0x0283,
  opened: false,
  oninputreport,
  collections: [
    { usage: 1, usagePage: 140, },
    { usage: 97, usagePage: 65376, },
  ],
  ...mockedKbCalls,
};

navigator.hid.requestDevice = async (filters) => {
  console.log(`request device with filters`, filters);
  return [hiddev];
};
