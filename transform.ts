import { mergeReadableStreams } from "@std/streams"
import { z } from "zod"

const filename = Deno.args[0]

console.log("a")

const resultsSchema = z.object({
	attr: z.string(),
	type: z.string(),
	success: z.boolean(),
	error: z.string().nullable(),
})

const resultsWrapperSchema = z.object({
	results: z.array(resultsSchema),
})

type ResultsWrapper = z.infer<typeof resultsWrapperSchema>

const results: ResultsWrapper = resultsWrapperSchema.parse(
	JSON.parse(await Deno.readTextFile(filename)),
)

results.results = await Promise.all(results.results.map(async (status) => {
	switch (status.type) {
		case "EVAL": {
			if (status.success) {
				return status
			} else {
				const process = new Deno.Command("script", {
					args: [
						"-efq",
						"-c",
						`nix eval --show-trace ".#checks.${status.attr}"`,
					],
					env: {
						"TERM": "xterm-256color",
					},
					stdin: "null",
					stdout: "piped",
					stderr: "piped",
				}).spawn()
				const joined = mergeReadableStreams(
					process.stdout,
					process.stderr,
				)
				const tmpfile_path = await Deno.makeTempFile({ suffix: "error" })
				const tmpfile = await Deno.open(
					tmpfile_path,
					{
						read: true,
						write: true,
						create: true,
					},
				)
				joined.pipeTo(tmpfile.writable)
				await process.status
				//await Deno.remove("./typescript")
				status.error = await Deno.readTextFile(tmpfile_path)
				return status
			}
		}
		default: {
			return status
		}
	}
}))

await Deno.writeTextFile("./result_parsed.json", JSON.stringify(results, null, "\t"))
