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

const runCommandScriptColor = async (command: string): Promise<string> => {
	const tmpfile_path = await Deno.makeTempFile({ suffix: "error" })
	const tmpfile = await Deno.open(
		tmpfile_path,
		{
			read: true,
			write: true,
			create: true,
		},
	)
	const process = new Deno.Command("script", {
		args: [
			"-efq",
			"-c",
			command,
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
	joined.pipeTo(tmpfile.writable)
	await process.status
	try {
		await Deno.remove("./typescript")
	} catch (e) {
		if (e instanceof Deno.errors.NotFound) {
			// ignore
		} else {
			throw e
		}
	}
	const output = await Deno.readTextFile(tmpfile_path)
	await Deno.remove(tmpfile_path)
	return output
}

results.results = await Promise.all(results.results.map(async (status) => {
	switch (status.type) {
		case "EVAL": {
			if (status.success) {
				return status
			} else {
				status.error = await runCommandScriptColor(
					`nix eval --show-trace ".#checks.${status.attr}"`,
				)
				return status
			}
		}
		case "BUILD": {
			status.error = await runCommandScriptColor(`nix log ".#checks.${status.attr}"`)
			return status
		}
		default: {
			return status
		}
	}
}))

await Deno.writeTextFile(
	"./result_parsed.json",
	JSON.stringify(results, null, "\t"),
)
