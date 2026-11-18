package main

import (
	"math"
	"time"

	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/shader"
)

// caramelGooShader renders up to 3 rounded-rectangle blobs merged via smooth
// polynomial union (metaball adhesion) on the GPU. Text sits above this layer
// in the view tree so glyphs are never blurred or distorted.
var caramelGooShader = shader.MustCompile(`package main

var BlobA vec4     // cx, cy, halfW, halfH
var BlobB vec4     // cx, cy, halfW, halfH
var BlobC vec4     // cx, cy, halfW, halfH (optional syrup droplet / neck)
var Radii vec4     // rA, rB, rC, smoothK
var FillColor vec4 // main caramel color (sRGB, non-premultiplied)
var SheenColor vec4

func sdRoundBox(p vec2, b vec2, r float) float {
	rr := min(r, min(b.x, b.y))
	q := abs(p) - b + vec2(rr, rr)
	return length(max(q, vec2(0, 0))) + min(max(q.x, q.y), 0) - rr
}

func smin(a float, b float, k float) float {
	if k <= 0.001 {
		return min(a, b)
	}
	h := max(k-abs(a-b), 0) / k
	return min(a, b) - h*h*k*0.25
}

func Fragment(dst vec4, pos vec2) vec4 {
	d := 1e6
	k := Radii.w

	if BlobA.z > 0.5 && BlobA.w > 0.5 {
		d = sdRoundBox(pos-BlobA.xy, BlobA.zw, Radii.x)
	}
	if BlobB.z > 0.5 && BlobB.w > 0.5 {
		db := sdRoundBox(pos-BlobB.xy, BlobB.zw, Radii.y)
		if d > 1e5 {
			d = db
		} else {
			d = smin(d, db, k)
		}
	}
	if BlobC.z > 0.5 && BlobC.w > 0.5 {
		dc := sdRoundBox(pos-BlobC.xy, BlobC.zw, Radii.z)
		if d > 1e5 {
			d = dc
		} else {
			d = smin(d, dc, k*0.85)
		}
	}

	if d > 1.5 {
		return vec4(0, 0, 0, 0)
	}

	cov := 1.0 - smoothstep(-0.75, 0.75, d)
	if cov <= 0.001 {
		return vec4(0, 0, 0, 0)
	}

	// Subtle top caramel warmth sheen without distorting text or acting as glass.
	size := rectSize()
	t := clamp(1.0-pos.y/max(size.y, 1.0), 0.0, 1.0)
	rgb := mix(FillColor.rgb, SheenColor.rgb, t*t*SheenColor.a)
	a := FillColor.a * cov
	return vec4(rgb*a, a)
}
`)

var (
	uBlobA      = caramelGooShader.Uniform("BlobA")
	uBlobB      = caramelGooShader.Uniform("BlobB")
	uBlobC      = caramelGooShader.Uniform("BlobC")
	uRadii      = caramelGooShader.Uniform("Radii")
	uFillColor  = caramelGooShader.Uniform("FillColor")
	uSheenColor = caramelGooShader.Uniform("SheenColor")
)

type caramelBlob struct {
	cx, cy, w, h, r float32
}

func (b caramelBlob) valid() bool {
	return b.w > 1 && b.h > 1
}

func blobFromRect(r ui.Rect, radius float32) caramelBlob {
	if r.W <= 0 || r.H <= 0 {
		return caramelBlob{}
	}
	rad := radius
	if maxR := min(r.W, r.H) * 0.5; rad > maxR {
		rad = maxR
	}
	return caramelBlob{
		cx: r.X + r.W*0.5,
		cy: r.Y + r.H*0.5,
		w:  r.W,
		h:  r.H,
		r:  rad,
	}
}

func lerp32(a, b, t float32) float32 {
	return a + (b-a)*t
}

func clamp01(v float32) float32 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func lerpBlob(a, b caramelBlob, t float32) caramelBlob {
	return caramelBlob{
		cx: lerp32(a.cx, b.cx, t),
		cy: lerp32(a.cy, b.cy, t),
		w:  max(0, lerp32(a.w, b.w, t)),
		h:  max(0, lerp32(a.h, b.h, t)),
		r:  max(0, lerp32(a.r, b.r, t)),
	}
}

// Cubic bezier evaluator matching CSS timing functions used by caramel-pudding.
var (
	easePull   = ui.CubicBezier(0.30, 0.00, 0.50, 1.00)
	easeMove   = ui.CubicBezier(0.40, 0.00, 0.20, 1.00)
	easeWobble = ui.CubicBezier(0.45, 0.00, 0.55, 1.00)
	easeSnap   = ui.CubicBezier(0.55, 0.00, 0.80, 0.30)
	easePress  = ui.CubicBezier(0.34, 1.56, 0.64, 1.00)
	easeJelly  = ui.CubicBezier(0.30, 0.70, 0.40, 1.00)
	easePopIn  = ui.CubicBezier(0.20, 0.80, 0.30, 1.00)
)

// CaramelGroup tracks single-selection geometry and gooey caramel syrup flow
// across a row or column of rounded buttons.
type CaramelGroup struct {
	selected  int
	prev      int
	hasInit   bool
	animating bool
	startTime time.Time
	duration  time.Duration
	distant   bool

	rowBounds ui.Rect
	itemRects map[int]ui.Rect
	holdIdx   int
	holdStart time.Time
	radius    float32
}

func newCaramelGroup(radius float32) *CaramelGroup {
	return &CaramelGroup{
		selected:  0,
		prev:      0,
		holdIdx:   -1,
		radius:    radius,
		itemRects: make(map[int]ui.Rect),
	}
}

// Sync updates the active index and triggers gooey flow whenever selection moves.
func (g *CaramelGroup) Sync(c *ui.Context, active int) {
	if !g.hasInit {
		g.selected = active
		g.prev = active
		g.hasInit = true
		return
	}
	if active == g.selected {
		return
	}
	g.prev = g.selected
	g.selected = active
	g.holdIdx = -1
	if c.Preferences().ReduceMotion {
		g.animating = false
		return
	}
	delta := active - g.prev
	if delta < 0 {
		delta = -delta
	}
	g.distant = delta > 1
	baseMs := 500 * time.Millisecond
	if g.distant {
		baseMs = 580 * time.Millisecond
	}
	g.startTime = c.Now()
	g.duration = baseMs
	g.animating = true
	c.Invalidate()
}

// RecordRow captures the container's layout bounds from the previous frame.
func (g *CaramelGroup) RecordRow(el ui.Element) {
	b := el.LayoutBounds()
	if b.W > 0 && b.H > 0 {
		g.rowBounds = b
	}
}

// RecordItem captures an item's local rect inside the row and tracks pointer hold
// for pre-release surface-tension pull.
func (g *CaramelGroup) RecordItem(c *ui.Context, idx int, el ui.Element) {
	b := el.LayoutBounds()
	if b.W > 0 && b.H > 0 && g.rowBounds.W > 0 {
		g.itemRects[idx] = ui.Rect{
			X: b.X - g.rowBounds.X,
			Y: b.Y - g.rowBounds.Y,
			W: b.W,
			H: b.H,
		}
	}
	if el.Pressed() && idx != g.selected {
		if g.holdIdx != idx {
			g.holdIdx = idx
			g.holdStart = c.Now()
		}
		if !c.Preferences().ReduceMotion {
			c.Invalidate()
		}
	} else if g.holdIdx == idx && !el.Pressed() {
		g.holdIdx = -1
		if !c.Preferences().ReduceMotion {
			c.Invalidate()
		}
	}
}

// TextMix returns [0..1] indicating how strongly item idx should use the active
// text color, matching caramel-pudding's ink handoff (old dims 30%->60%, new
// brightens 42%->72%).
func (g *CaramelGroup) TextMix(c *ui.Context, idx int) float32 {
	if !g.animating {
		if idx == g.selected {
			return 1
		}
		return 0
	}
	t := g.progress(c.Now())
	if idx == g.prev {
		return 1 - clamp01((t-0.30)/0.30)
	}
	if idx == g.selected {
		return clamp01((t - 0.42) / 0.30)
	}
	return 0
}

func (g *CaramelGroup) progress(now time.Time) float32 {
	if !g.animating || g.duration <= 0 {
		return 1
	}
	elapsed := now.Sub(g.startTime)
	if elapsed <= 0 {
		return 0
	}
	if elapsed >= g.duration {
		return 1
	}
	return float32(elapsed) / float32(g.duration)
}

// Paint renders the gooey caramel indicator behind the row's buttons.
func (g *CaramelGroup) Paint(p *ui.Painter, r ui.Rect, fill, sheen ui.Color, reduceMotion bool) {
	targetRect, ok := g.itemRects[g.selected]
	if !ok || targetRect.W <= 0 || targetRect.H <= 0 {
		return
	}
	rad := g.radius
	if rad <= 0 {
		rad = min(targetRect.W, targetRect.H) * 0.5
	}

	var blobA, blobB, blobC caramelBlob
	var smoothK float32

	now := p.Now()
	if g.animating && !reduceMotion {
		t := g.progress(now)
		prevRect, hasPrev := g.itemRects[g.prev]
		if !hasPrev || t >= 1 {
			g.animating = false
			blobB = blobFromRect(targetRect, rad)
		} else {
			A := blobFromRect(prevRect, rad)
			B := blobFromRect(targetRect, rad)
			blobA, blobB, blobC, smoothK = evalCaramelFlow(A, B, t, g.distant)
			p.AnimationFrame()
		}
	} else {
		g.animating = false
		blobB = blobFromRect(targetRect, rad)
		// Pre-release surface tension pull toward held sibling.
		if g.holdIdx >= 0 && g.holdIdx != g.selected && !reduceMotion {
			if holdRect, ok := g.itemRects[g.holdIdx]; ok {
				holdT := clamp01(float32(now.Sub(g.holdStart).Seconds()) / 0.22)
				holdT = easePull(holdT)
				H := blobFromRect(holdRect, rad)
				dx := H.cx - blobB.cx
				dy := H.cy - blobB.cy
				dist := float32(math.Hypot(float64(dx), float64(dy)))
				if dist > 1 {
					ux, uy := dx/dist, dy/dist
					pull := float32(6.0) * holdT
					if math.Abs(float64(ux)) >= math.Abs(float64(uy)) {
						blobB.cx += ux * pull * 0.5
						blobB.w += pull
					} else {
						blobB.cy += uy * pull * 0.5
						blobB.h += pull
					}
					// Small surface-tension bud on the held item's near edge.
					bud := min(H.w, H.h) * 0.34 * holdT
					edgeX := H.cx - ux*(H.w*0.42)
					edgeY := H.cy - uy*(H.h*0.42)
					blobC = caramelBlob{cx: edgeX, cy: edgeY, w: bud, h: bud, r: bud * 0.5}
					smoothK = min(blobB.h, blobB.w) * 0.32
				}
				if holdT < 1 {
					p.AnimationFrame()
				}
			}
		}
	}

	// Fast CPU fallback for ui.NewTester / software renderers.
	if !p.Accelerated() {
		drawBlobFallback := func(b caramelBlob) {
			if !b.valid() {
				return
			}
			rr := ui.Rect{
				X: r.X + b.cx - b.w*0.5,
				Y: r.Y + b.cy - b.h*0.5,
				W: b.w,
				H: b.h,
			}
			p.Fill(rr, fill, min(b.r, min(b.w, b.h)*0.5))
		}
		drawBlobFallback(blobA)
		drawBlobFallback(blobC)
		drawBlobFallback(blobB)
		return
	}

	vals := caramelGooShader.NewValues()
	vals.Vec4(uBlobA, blobA.cx, blobA.cy, blobA.w*0.5, blobA.h*0.5)
	vals.Vec4(uBlobB, blobB.cx, blobB.cy, blobB.w*0.5, blobB.h*0.5)
	vals.Vec4(uBlobC, blobC.cx, blobC.cy, blobC.w*0.5, blobC.h*0.5)
	vals.Vec4(uRadii, blobA.r, blobB.r, blobC.r, smoothK)
	vals.Color(uFillColor, fill)
	vals.Color(uSheenColor, sheen)

	caramelGooShader.Draw(p, r, shader.Options{Values: vals})
}

// evalCaramelFlow computes the exact caramel-pudding blob keyframes at progress
// t in [0..1] for adjacent and distant transitions.
func evalCaramelFlow(A, B caramelBlob, t float32, distant bool) (caramelBlob, caramelBlob, caramelBlob, float32) {
	dx := B.cx - A.cx
	dy := B.cy - A.cy
	dist := float32(math.Hypot(float64(dx), float64(dy)))
	if dist < 1 {
		return caramelBlob{}, B, caramelBlob{}, 0
	}
	ux, uy := dx/dist, dy/dist
	hz := math.Abs(float64(ux)) >= math.Abs(float64(uy))
	minThick := min(min(A.w, A.h), min(B.w, B.h))

	// Edge of B facing A.
	var eBx, eBy float32
	if hz {
		eBx = B.cx - ux*B.w*0.5
		eBy = B.cy
	} else {
		eBx = B.cx
		eBy = B.cy - uy*B.h*0.5
	}

	var outA, outB, outC caramelBlob

	if !distant {
		// Adjacent flow: old stretches -> contracts toward B -> absorbed;
		// new buds -> swells -> overshoots 103.5%x95.5% -> 99%x102% -> settles.
		stretch := float32(5.0)
		aPull := A
		if hz {
			aPull.cx += ux * stretch * 0.5
			aPull.w += stretch
		} else {
			aPull.cy += uy * stretch * 0.5
			aPull.h += stretch
		}
		aMid := caramelBlob{
			cx: A.cx + ux*dist*0.26,
			cy: A.cy + uy*dist*0.26,
			w:  A.w * 0.60,
			h:  A.h * 0.72,
			r:  minThick * 0.36,
		}
		if !hz {
			aMid.w, aMid.h = A.w*0.72, A.h*0.60
		}
		aDot := caramelBlob{cx: eBx, cy: eBy, w: minThick * 0.42, h: minThick * 0.42, r: minThick * 0.21}
		aGone := caramelBlob{cx: eBx + ux*minThick*0.25, cy: eBy + uy*minThick*0.25, w: 0, h: 0, r: 0}

		switch {
		case t < 0.16:
			outA = lerpBlob(A, aPull, easePull(t/0.16))
		case t < 0.40:
			outA = lerpBlob(aPull, aMid, easeMove((t-0.16)/0.24))
		case t < 0.64:
			outA = lerpBlob(aMid, aDot, easeSnap((t-0.40)/0.24))
		case t < 0.82:
			outA = lerpBlob(aDot, aGone, (t-0.64)/0.18)
		}

		bZero := caramelBlob{cx: eBx, cy: eBy, w: 0, h: 0, r: 0}
		bBud := caramelBlob{
			cx: eBx + ux*minThick*0.20,
			cy: eBy + uy*minThick*0.20,
			w:  minThick * 0.42,
			h:  minThick * 0.42,
			r:  minThick * 0.21,
		}
		bGrow := caramelBlob{
			cx: B.cx - ux*(B.w*0.14),
			cy: B.cy - uy*(B.h*0.14),
			w:  B.w * 0.70,
			h:  B.h * 0.82,
			r:  B.r,
		}
		if !hz {
			bGrow.w, bGrow.h = B.w*0.82, B.h*0.70
		}
		bOver1 := caramelBlob{cx: B.cx, cy: B.cy, w: B.w * 1.035, h: B.h * 0.955, r: B.r}
		bOver2 := caramelBlob{cx: B.cx, cy: B.cy, w: B.w * 0.99, h: B.h * 1.02, r: B.r}
		if !hz {
			bOver1.w, bOver1.h = B.w*0.955, B.h*1.035
			bOver2.w, bOver2.h = B.w*1.02, B.h*0.99
		}

		switch {
		case t < 0.26:
			outB = lerpBlob(bZero, bBud, easeMove(t/0.26))
		case t < 0.46:
			outB = lerpBlob(bBud, bGrow, easeWobble((t-0.26)/0.20))
		case t < 0.68:
			outB = lerpBlob(bGrow, bOver1, easeWobble((t-0.46)/0.22))
		case t < 0.84:
			outB = lerpBlob(bOver1, bOver2, easeWobble((t-0.68)/0.16))
		default:
			outB = lerpBlob(bOver2, B, easeWobble((t-0.84)/0.16))
		}

		// Liquid bridge droplet during mid-transition for pronounced caramel stringing.
		if t > 0.14 && t < 0.56 {
			nt := (t - 0.14) / 0.42
			arc := float32(math.Sin(float64(nt) * math.Pi))
			midX := lerp32(A.cx, B.cx, 0.35+0.35*nt)
			midY := lerp32(A.cy, B.cy, 0.35+0.35*nt)
			w := minThick * 0.58 * arc
			h := minThick * 0.34 * arc
			if !hz {
				w, h = h, w
			}
			outC = caramelBlob{cx: midX, cy: midY, w: w, h: h, r: min(w, h) * 0.5}
		}

		// Smooth-min adhesion peaks while blobs are crossing the gap, settles to 0.
		adhesion := float32(math.Sin(float64(clamp01(t/0.85)) * math.Pi))
		smoothK := minThick * 0.52 * adhesion
		return outA, outB, outC, smoothK
	}

	// Distant flow: old pinches into a syrup droplet that streaks across to B,
	// then B blooms with wobble once the droplet lands.
	aShrink := caramelBlob{cx: A.cx + ux*minThick*0.3, cy: A.cy + uy*minThick*0.3, w: 0, h: 0, r: 0}
	if t < 0.38 {
		outA = lerpBlob(A, aShrink, easeSnap(t/0.38))
	}

	if t > 0.10 && t < 0.68 {
		dt := easeMove((t - 0.10) / 0.58)
		dropX := lerp32(A.cx, B.cx, dt)
		dropY := lerp32(A.cy, B.cy, dt)
		streak := float32(math.Sin(float64(dt) * math.Pi))
		al := minThick * (0.48 + 0.55*streak)
		cr := minThick * (0.42 - 0.10*streak)
		if hz {
			outC = caramelBlob{cx: dropX, cy: dropY, w: al, h: cr, r: cr * 0.5}
		} else {
			outC = caramelBlob{cx: dropX, cy: dropY, w: cr, h: al, r: cr * 0.5}
		}
	}

	if t > 0.44 {
		bt := (t - 0.44) / 0.56
		bZero := caramelBlob{cx: eBx, cy: eBy, w: minThick * 0.28, h: minThick * 0.28, r: minThick * 0.14}
		bOver1 := caramelBlob{cx: B.cx, cy: B.cy, w: B.w * 1.04, h: B.h * 0.95, r: B.r}
		bOver2 := caramelBlob{cx: B.cx, cy: B.cy, w: B.w * 0.99, h: B.h * 1.02, r: B.r}
		switch {
		case bt < 0.42:
			outB = lerpBlob(bZero, bOver1, easePopIn(bt/0.42))
		case bt < 0.72:
			outB = lerpBlob(bOver1, bOver2, easeWobble((bt-0.42)/0.30))
		default:
			outB = lerpBlob(bOver2, B, easeWobble((bt-0.72)/0.28))
		}
	}

	smoothK := minThick * 0.42 * float32(math.Sin(float64(clamp01(t/0.88))*math.Pi))
	return outA, outB, outC, smoothK
}

// puddingState lives inside ui.Local for each jelly-interactive card or button.
type puddingState struct {
	wasPressed bool
	pressStart time.Time
	releasing  bool
	relStart   time.Time
	fromSX     float32
	fromSY     float32
	curSX      float32
	curSY      float32
}

// applyPudding attaches Caramel Pudding's exact 6-stop jelly press & release
// physics to an element (cards, metric tiles, big buttons).
// amp matches caramel-pudding's size tiers: card ~0.72, tile ~0.60, big ~0.65.
func applyPudding(c *ui.Context, el ui.Element, amp float32) {
	if c.Preferences().ReduceMotion {
		return
	}
	st := ui.Local(el, "cp-pudding", func() puddingState {
		return puddingState{curSX: 1, curSY: 1, fromSX: 1, fromSY: 1}
	})
	now := c.Now()
	pressed := el.Pressed()

	if pressed {
		if !st.wasPressed {
			st.wasPressed = true
			st.releasing = false
			st.pressStart = now
			st.fromSX = st.curSX
			st.fromSY = st.curSY
		}
		const dur = 0.34
		t := clamp01(float32(now.Sub(st.pressStart).Seconds() / dur))
		target := 1 - 0.075*amp
		e := easePress(t)
		st.curSX = lerp32(st.fromSX, target, e)
		st.curSY = lerp32(st.fromSY, target, e)
		el.Scale(st.curSX, st.curSY)
		if t < 1 {
			c.Invalidate()
		}
		return
	}

	if st.wasPressed {
		st.wasPressed = false
		st.releasing = true
		st.relStart = now
		st.fromSX = st.curSX
		st.fromSY = st.curSY
	}

	if st.releasing {
		const dur = 0.70
		t := float32(now.Sub(st.relStart).Seconds() / dur)
		if t >= 1 {
			st.releasing = false
			st.curSX, st.curSY = 1, 1
			return
		}
		sx, sy := evalPuddingRelease(st.fromSX, st.fromSY, amp, clamp01(t))
		st.curSX, st.curSY = sx, sy
		el.Scale(sx, sy)
		c.Invalidate()
	}
}

// evalPuddingRelease evaluates Caramel Pudding's 6-stop squash-and-stretch
// release keyframes:
//
//	0.00: (fromSX, fromSY)
//	0.28: (1 + .12a,  1 - .13a)
//	0.48: (1 - .07a,  1 + .08a)
//	0.66: (1 + .035a, 1 - .035a)
//	0.82: (1 - .012a, 1 + .012a)
//	1.00: (1, 1)
func evalPuddingRelease(fromSX, fromSY, a, t float32) (float32, float32) {
	type stop struct {
		at, sx, sy float32
	}
	stops := [...]stop{
		{0.00, fromSX, fromSY},
		{0.28, 1 + 0.12*a, 1 - 0.13*a},
		{0.48, 1 - 0.07*a, 1 + 0.08*a},
		{0.66, 1 + 0.035*a, 1 - 0.035*a},
		{0.82, 1 - 0.012*a, 1 + 0.012*a},
		{1.00, 1.0, 1.0},
	}
	for i := 0; i < len(stops)-1; i++ {
		if t <= stops[i+1].at {
			seg := (t - stops[i].at) / (stops[i+1].at - stops[i].at)
			e := easeJelly(clamp01(seg))
			return lerp32(stops[i].sx, stops[i+1].sx, e), lerp32(stops[i].sy, stops[i+1].sy, e)
		}
	}
	return 1, 1
}

// applyTinyFade applies Caramel Pudding's "tiny" tier: subtle opacity fade on
// press with zero scale wobble (for icon buttons, toggles, compact links).
func applyTinyFade(el ui.Element) {
	if el.Pressed() {
		el.Opacity(0.62)
	}
}

// evalPopEntrance computes Caramel Pudding's `cp-pop` 580ms overlay entrance:
// rises from below with a gentle jelly settle.
func evalPopEntrance(t float32) (opacity, dy, sx, sy float32) {
	t = clamp01(t)
	switch {
	case t < 0.50:
		u := easePopIn(t / 0.50)
		return u, lerp32(24, -4, u), lerp32(0.86, 1.03, u), lerp32(0.86, 0.975, u)
	case t < 0.70:
		u := easeWobble((t - 0.50) / 0.20)
		return 1, lerp32(-4, 1, u), lerp32(1.03, 0.988, u), lerp32(0.975, 1.016, u)
	case t < 0.86:
		u := easeWobble((t - 0.70) / 0.16)
		return 1, lerp32(1, 0, u), lerp32(0.988, 1.004, u), lerp32(1.016, 0.997, u)
	default:
		u := easeWobble((t - 0.86) / 0.14)
		return 1, 0, lerp32(1.004, 1, u), lerp32(0.997, 1, u)
	}
}

// evalMenuEntrance computes Caramel Pudding's `cp-menu` 600ms entrance growing
// out from the pointer's origin.
func evalMenuEntrance(t float32) (opacity, sx, sy float32) {
	t = clamp01(t)
	opacity = clamp01(t / 0.18)
	switch {
	case t < 0.46:
		u := easePopIn(t / 0.46)
		return opacity, lerp32(0.16, 1.05, u), lerp32(0.10, 0.955, u)
	case t < 0.66:
		u := easeWobble((t - 0.46) / 0.20)
		return 1, lerp32(1.05, 0.982, u), lerp32(0.955, 1.03, u)
	case t < 0.84:
		u := easeWobble((t - 0.66) / 0.18)
		return 1, lerp32(0.982, 1.007, u), lerp32(1.03, 0.993, u)
	default:
		u := easeWobble((t - 0.84) / 0.16)
		return 1, lerp32(1.007, 1, u), lerp32(0.993, 1, u)
	}
}
