/**
 * lxii-reasoning-text
 *
 * 背景：lxii 网关（sub2.lxii.cc）在 thinking 模式下校验多轮对话里的
 * assistant 消息必须回传 `reasoning_text` 字段，否则返回 400：
 *   "The `reasoning_text` in the thinking mode must be passed back to the API."
 *
 * 而 pi 按 DeepSeek 官方格式只写 `reasoning_content`（官方字段名），
 * 两个字段名不一致导致偶发 400。
 *
 * 本扩展在请求发出前（before_provider_request）把所有 assistant 消息的
 * reasoning_content 同步一份到 reasoning_text，两个字段都带上，
 * 同时满足 DeepSeek 官方与 lxii 网关的校验。
 *
 * 只对 provider 为 lxiid（lxii 网关）的请求生效，不影响官方 DeepSeek 等其他 provider。
 * 修改后无需重启 pi，在会话里执行 /reload 即可生效。
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event, ctx) => {
		// 只处理 lxii 网关的请求
		const model = ctx.model;
		if (!model || model.provider !== "lxiid") return;

		const payload = event.payload as
			| { messages?: Array<Record<string, unknown>> }
			| undefined;
		if (!payload || !Array.isArray(payload.messages)) return;

		let changed = false;
		for (const msg of payload.messages) {
			if (msg.role !== "assistant") continue;
			// reasoning_content 存在但 reasoning_text 缺失时补一份
			if (msg.reasoning_content !== undefined && msg.reasoning_text === undefined) {
				msg.reasoning_text = msg.reasoning_content;
				changed = true;
			}
		}
		return changed ? payload : undefined;
	});
}
