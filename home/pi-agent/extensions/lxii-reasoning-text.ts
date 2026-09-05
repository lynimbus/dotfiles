import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event, ctx) => {
		const model = ctx.model;
		if (!model || model.provider !== "lxiid") return;

		const payload = event.payload as
			| { messages?: Array<Record<string, unknown>> }
			| undefined;
		if (!payload || !Array.isArray(payload.messages)) return;

		let changed = false;
		for (const msg of payload.messages) {
			if (msg.role !== "assistant") continue;
			if (msg.reasoning_content !== undefined && msg.reasoning_text === undefined) {
				msg.reasoning_text = msg.reasoning_content;
				changed = true;
			}
		}
		return changed ? payload : undefined;
	});
}
