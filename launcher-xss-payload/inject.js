const oldJsonParse = JSON.parse;
JSON.parse = (...args) => {
    const res = oldJsonParse(...args);
    if (res && res.data && res.data.firmware && res.data.firmware.lasted && res.data.firmware.lasted.path)
        res.data.firmware.lasted.path = "http://localhost:8080/firmware.bin";
    console.log(res);
    return res;
}

