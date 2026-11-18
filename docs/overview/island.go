package main

import (
	"math"
	"time"

	"github.com/egoist/mygo/ui"
)

// islandShape describes real layout dimensions (never scale) for CaramelIsland.
type islandShape struct {
	W, H, R float64
}

type islandPhase int

const (
	islandStill islandPhase = iota
	islandExpand
	islandShrink
	islandPop
)

type springParams struct {
	K, Z float64
}

// Exact spring constants from wave2234/caramel-pudding/island.js.
var islandPhases = map[islandPhase]springParams{
	islandExpand: {K: 280, Z: 0.80}, // slight gentle overshoot on open
	islandShrink: {K: 1200, Z: 1.0}, // critically damped, crisp 190ms collapse
	islandPop:    {K: 200, Z: 0.65}, // light bounce when pill content changes
}

// springStep advances a unit-mass damped harmonic oscillator analytically over
// dt seconds. Exact analytical stepping is unconditionally stable at any FPS.
func springStep(x, v, goal, k, z, dt float64) (float64, float64) {
	d := x - goal
	w := math.Sqrt(k)
	decay := math.Exp(-z * w * dt)
	if z >= 1.0 {
		b := v + w*d
		return goal + (d+b*dt)*decay, (v - w*b*dt) * decay
	}
	wd := w * math.Sqrt(1.0-z*z)
	b := (v + z*w*d) / wd
	c := math.Cos(wd * dt)
	s := math.Sin(wd * dt)
	off := d*c + b*s
	return goal + off*decay, ((-d*wd*s + b*wd*c) - z*w*off) * decay
}

// CaramelIsland implements the floating top status capsule using three
// analytical damped springs (width, height, corner radius).
type CaramelIsland struct {
	bean     islandShape
	v        [3]float64
	vel      [3]float64
	start    islandShape
	target   islandShape
	final    islandShape
	phase    islandPhase
	age      float64
	expanded bool

	inA      float64
	outA     float64
	lastTick time.Time

	// Transient pill message (e.g., copy confirmation or refresh status).
	noticeText  string
	noticeUntil time.Time
}

func newCaramelIsland() *CaramelIsland {
	bean := islandShape{W: 184, H: 34, R: 17}
	return &CaramelIsland{
		bean:   bean,
		v:      [3]float64{bean.W, bean.H, bean.R},
		start:  bean,
		target: bean,
		final:  bean,
		phase:  islandStill,
		inA:    1,
	}
}

func (is *CaramelIsland) To(goal islandShape, open, reduceMotion bool, now time.Time) {
	is.final = goal
	is.expanded = open
	if reduceMotion {
		is.v = [3]float64{goal.W, goal.H, goal.R}
		is.vel = [3]float64{}
		is.phase = islandStill
		is.inA = 1
		is.outA = 0
		is.lastTick = now
		return
	}
	is.inA = 0
	is.outA = 1
	is.lastTick = now
	if !open && (is.v[1] > is.bean.H+0.5 || is.phase == islandExpand) {
		is.begin(islandShrink, is.bean)
	} else if open {
		is.begin(islandExpand, goal)
	} else {
		is.begin(islandPop, goal)
	}
}

func (is *CaramelIsland) begin(p islandPhase, goal islandShape) {
	is.phase = p
	is.age = 0
	is.start = islandShape{W: is.v[0], H: is.v[1], R: is.v[2]}
	is.target = goal
}

func (is *CaramelIsland) progress() float64 {
	d := is.target.W - is.start.W
	if math.Abs(d) < 0.5 {
		return math.Min(1, is.age/0.20)
	}
	p := (is.v[0] - is.start.W) / d
	if p < 0 {
		return 0
	}
	if p > 1.1 {
		return 1.1
	}
	return p
}

// Step advances the island springs up to now, requesting another frame only
// while the springs are in motion.
func (is *CaramelIsland) Step(c *ui.Context, speed float64) {
	now := c.Now()
	if is.noticeText != "" && !is.noticeUntil.IsZero() && now.After(is.noticeUntil) {
		is.noticeText = ""
		if !is.expanded {
			is.To(is.bean, false, c.Preferences().ReduceMotion, now)
		}
	}
	if is.phase == islandStill {
		is.lastTick = now
		return
	}
	if c.Preferences().ReduceMotion {
		is.v = [3]float64{is.final.W, is.final.H, is.final.R}
		is.vel = [3]float64{}
		is.inA = 1
		is.outA = 0
		is.phase = islandStill
		is.lastTick = now
		return
	}
	if speed <= 0 {
		speed = 1
	}
	dt := 1.0 / 60.0
	if !is.lastTick.IsZero() {
		raw := now.Sub(is.lastTick).Seconds()
		if raw > 0 {
			dt = math.Min(0.05, raw)
		}
	}
	is.lastTick = now
	is.advance(dt * speed)
	if is.phase != islandStill {
		c.Invalidate()
	}
}

func (is *CaramelIsland) advance(dt float64) {
	if is.phase == islandStill {
		return
	}
	is.age += dt
	fadeWindow := 0.05
	if is.expanded {
		fadeWindow = 0.06
	}
	is.outA = math.Max(0, math.Min(1, 1-is.age/fadeWindow))

	params := islandPhases[is.phase]
	goals := [3]float64{is.target.W, is.target.H, is.target.R}
	for i := 0; i < 3; i++ {
		is.v[i], is.vel[i] = springStep(is.v[i], is.vel[i], goals[i], params.K, params.Z, dt)
	}

	switch is.phase {
	case islandShrink:
		is.inA = 0
		// Two-stage collapse from island.js: after 190ms snap height/radius
		// back to capsule, then settle width horizontally with pop spring.
		if is.age >= 0.19 {
			is.v[1] = is.bean.H
			is.v[2] = is.bean.R
			is.vel[1], is.vel[2] = 0, 0
			is.begin(islandPop, is.final)
		}
	case islandExpand:
		a := math.Max(0, math.Min(1, (is.age-0.075)/0.225))
		if is.progress() < 0.40 {
			is.inA = 0
		} else {
			is.inA = a
		}
	case islandPop:
		pr := is.progress()
		is.inA = math.Max(0, math.Min(1, (pr-0.20)/0.60))
	}

	minSettle := 0.55
	if is.phase == islandPop {
		minSettle = 0.57
	}
	if (is.phase == islandExpand || is.phase == islandPop) && is.age+0.0001 >= minSettle {
		starts := [3]float64{is.start.W, is.start.H, is.start.R}
		ok := true
		for i := 0; i < 3; i++ {
			tol := math.Max(is.bean.H/30.0, math.Abs(goals[i]-starts[i])*0.006)
			if math.Abs(is.v[i]-goals[i]) > tol || math.Abs(is.vel[i]) > tol*8 {
				ok = false
				break
			}
		}
		if ok {
			is.v = goals
			is.vel = [3]float64{}
			is.inA = 1
			is.outA = 0
			is.phase = islandStill
		}
	}
}

func (is *CaramelIsland) Width() float32  { return float32(math.Max(60, is.v[0])) }
func (is *CaramelIsland) Height() float32 { return float32(math.Max(28, is.v[1])) }
func (is *CaramelIsland) Radius() float32 { return float32(math.Max(8, is.v[2])) }
func (is *CaramelIsland) ContentAlpha() float32 {
	if is.phase == islandStill {
		return 1
	}
	return float32(is.inA)
}

func (is *CaramelIsland) Flash(c *ui.Context, text string, dur time.Duration, reduceMotion bool) {
	now := c.Now()
	is.noticeText = text
	is.noticeUntil = now.Add(dur)
	if !is.expanded {
		w := math.Max(190, math.Min(340, float64(len([]rune(text))*9+76)))
		is.To(islandShape{W: w, H: 34, R: 17}, false, reduceMotion, now)
	}
	c.After(dur + 40*time.Millisecond)
}

func (is *CaramelIsland) Toggle(c *ui.Context, winWidth float32) {
	now := c.Now()
	rm := c.Preferences().ReduceMotion
	if is.expanded {
		is.To(is.bean, false, rm, now)
	} else {
		w := math.Min(396, float64(winWidth-32))
		if w < 280 {
			w = 280
		}
		is.To(islandShape{W: w, H: 168, R: 32}, true, rm, now)
	}
}

func (is *CaramelIsland) Collapse(c *ui.Context) {
	if !is.expanded {
		return
	}
	is.To(is.bean, false, c.Preferences().ReduceMotion, c.Now())
}
