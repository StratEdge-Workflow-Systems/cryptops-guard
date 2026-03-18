#!/usr/bin/env node
"use strict";
const { execSync } = require("child_process");
execSync("node test.js", { stdio: "inherit" });
