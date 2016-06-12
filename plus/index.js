'use strict';

exports.handler = function process(evt, ctx, callback) {

    console.log("EVT: ", JSON.stringify(evt));

    var a = parseInt(evt.a || 1, 10),
        b = parseInt(evt.b || 2, 10),
        result = a + b;

    console.info("Maths " + a + " + " + b + " = " + result );
    callback(null, result);

};
