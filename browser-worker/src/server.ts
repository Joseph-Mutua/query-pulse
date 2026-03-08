import express from "express"
import { DiagnosticRunner } from "./diagnostic-runner.js"
import { UrlPolicy } from "./url-policy.js"

const app = express()
app.use(express.json({ limit: "16kb" }))
const allowedHosts = (process.env.ALLOWED_HOSTS ?? "www.google.com,www.bing.com").split(",").map((host) => host.trim().toLowerCase())
const runner = new DiagnosticRunner(new UrlPolicy(allowedHosts))

app.get("/health", (_request, response) => response.json({ status: "ok" }))
app.post("/diagnose", async (request, response) => {
  if (typeof request.body?.url !== "string") return response.status(422).json({ error: "url is required" })
  try {
    return response.json(await runner.run(request.body.url))
  } catch (error) {
    const message = error instanceof Error ? error.message : "invalid destination"
    return response.status(422).json({ error: message })
  }
})

app.listen(Number(process.env.PORT ?? 3100), "0.0.0.0")
