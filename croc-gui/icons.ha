// hpo croc — little drawings for the game cards, made from ViperGui shapes
// (no image files). Each fits in a box about 70 px across around (x, y).
use math;
use viper;

fn tri(win: *viper::window, a: (f64, f64), b: (f64, f64), c: (f64, f64), col: u32) void = {
	const p: [3](f64, f64) = [a, b, c];
	viper::polygon(win, p, col);
};

fn thick(win: *viper::window, x0: f64, y0: f64, x1: f64, y1: f64, w: int, col: u32) void = {
	for (let i = -w / 2; i <= w / 2; i += 1) {
		viper::line(win, x0: int + i, y0: int, x1: int + i, y1: int, col);
		viper::line(win, x0: int, y0: int + i, x1: int, y1: int + i, col);
	};
};

fn shine(win: *viper::window, x: f64, y: f64, r: int, base: u32, light: u32) void = {
	viper::circle(win, x: int, y: int, r, base);
	viper::circle(win, (x - r: f64 * 0.3): int, (y - r: f64 * 0.3): int, r / 3, light);
};

fn draw_icon(win: *viper::window, id: int, x: f64, y: f64, t: f64) void = {
	switch (id) {
	case 0 => // pinball: a ball and two flippers
		thick(win, x - 30.0, y + 18.0, x - 6.0, y + 28.0, 5, 0xffe8e8f0);
		thick(win, x + 30.0, y + 18.0, x + 6.0, y + 28.0, 5, 0xffe8e8f0);
		viper::circle(win, (x - 18.0): int, (y - 20.0): int, 9, 0xffd83a6a);
		viper::circle(win, (x + 16.0): int, (y - 24.0): int, 7, 0xffe8b83a);
		shine(win, x + math::sinf64(t * 2.0) * 10.0, y - 2.0, 9, 0xffc8ccd8, 0xffffffff);
	case 1 => // breakout: bricks, a ball and the bat
		const cols: [4]u32 = [0xffd83a3a, 0xffe8903a, 0xffe8d83a, 0xff3ad86a];
		for (let r = 0; r < 4; r += 1) for (let c = 0; c < 5; c += 1) {
			if ((r + c) % 3 == 0 && r > 1) continue;
			viper::rect(win, (x - 34.0): int + c * 14, (y - 30.0): int + r * 9, 12, 7, cols[r]);
		};
		viper::circle(win, (x + 6.0): int, (y + 12.0): int, 4, 0xffffffff);
		viper::round_rect(win, (x - 16.0): int, (y + 24.0): int, 32, 6, 3, 0xff9ab8ff);
	case 2 => // shooter: a ship and its shots
		tri(win, (x, y - 22.0), (x - 18.0, y + 20.0), (x + 18.0, y + 20.0), 0xffc8d0e8);
		tri(win, (x, y - 8.0), (x - 6.0, y + 14.0), (x + 6.0, y + 14.0), 0xff3a8ad8);
		viper::rect(win, (x - 4.0): int, (y + 20.0): int, 8, 6, 0xffff8a3a);
		const fy = math::modf64(t * 60.0, 30.0);
		viper::rect(win, (x - 1.0): int, (y - 30.0 - fy): int, 3, 8, 0xffffe86a);
	case 3 => // bubbles
		const b: [6](f64, f64, u32) = [(-16.0, -14.0, 0xffd83a3a), (2.0, -14.0, 0xff3a8ad8),
			(20.0, -14.0, 0xffe8d83a), (-7.0, 2.0, 0xff3ad86a), (11.0, 2.0, 0xffd83a3a),
			(2.0, 22.0, 0xffb83ad8)];
		for (let p .. b) shine(win, x + p.0, y + p.1, 9, p.2, 0xffffffff);
	case 4 => // dino footprint
		viper::circle(win, x: int, (y + 10.0): int, 15, 0xff5a3a1a);
		for (let i = -1; i <= 1; i += 1) {
			tri(win, (x + i: f64 * 13.0, y - 30.0 + math::absf64(i: f64) * 6.0),
				(x + i: f64 * 9.0 - 6.0, y - 4.0), (x + i: f64 * 9.0 + 6.0, y - 4.0), 0xff5a3a1a);
		};
	case 5 => // rings
		for (let i = 0; i < 3; i += 1) {
			const rx = x - 20.0 + i: f64 * 20.0;
			const ry = y + math::sinf64(t * 3.0 + i: f64) * 6.0;
			viper::circle(win, rx: int, ry: int, 11, 0xffffd23a);
			viper::circle(win, rx: int, ry: int, 6, 0xff1e3a24);
		};
	case 6 => // chequered flag
		thick(win, x - 26.0, y - 30.0, x - 26.0, y + 30.0, 3, 0xffc8c8c8);
		for (let r = 0; r < 4; r += 1) for (let c = 0; c < 5; c += 1) {
			viper::rect(win, (x - 24.0): int + c * 10, (y - 30.0): int + r * 9 +
				(math::sinf64(t * 4.0 + c: f64) * 2.0): int, 10, 9,
				if ((r + c) % 2 == 0) 0xffffffff else 0xff202020);
		};
	case 7 => // sword
		thick(win, x - 20.0, y + 22.0, x + 20.0, y - 22.0, 5, 0xffd0d8e8);
		thick(win, x - 22.0, y + 8.0, x - 6.0, y + 24.0, 4, 0xffe8b83a);
		viper::circle(win, (x - 24.0): int, (y + 26.0): int, 4, 0xffe8b83a);
	case 8 => // a "?" block
		viper::round_rect(win, (x - 22.0): int, (y - 22.0): int, 44, 44, 6, 0xffe8a82a);
		viper::round_rect(win, (x - 18.0): int, (y - 18.0): int, 36, 36, 4, 0xfff0c84a);
		viper::text_scaled(win, (x - 8.0): int, (y - 16.0): int, "?", 0xff8a4a10, 2);
	case 9 => // steering wheel
		viper::circle(win, x: int, y: int, 26, 0xff2a2a30);
		viper::circle(win, x: int, y: int, 19, 0xff1e3a24);
		thick(win, x - 19.0, y, x + 19.0, y, 5, 0xff2a2a30);
		thick(win, x, y, x, y + 19.0, 5, 0xff2a2a30);
		viper::circle(win, x: int, y: int, 6, 0xffd83a3a);
	case 10 => // lightning bolt
		const p: [6](f64, f64) = [(x + 8.0, y - 30.0), (x - 14.0, y + 4.0), (x - 1.0, y + 4.0),
			(x - 8.0, y + 30.0), (x + 14.0, y - 6.0), (x + 1.0, y - 6.0)];
		viper::polygon(win, p, 0xffffd23a);
	case 11 => // bomb
		viper::circle(win, (x - 4.0): int, (y + 6.0): int, 20, 0xff2a2a34);
		viper::circle(win, (x - 11.0): int, y: int, 5, 0xff5a5a6a);
		thick(win, x + 8.0, y - 10.0, x + 16.0, y - 22.0, 3, 0xffa08a5a);
		const sp = 4 + (math::sinf64(t * 12.0) * 2.0): int;
		viper::circle(win, (x + 18.0): int, (y - 25.0): int, sp, 0xffffb23a);
	case 12 => // slime
		viper::circle(win, x: int, (y + 6.0): int, 24, 0xff5ad84a);
		viper::rect(win, (x - 24.0): int, (y + 6.0): int, 49, 20, 0xff5ad84a);
		viper::circle(win, (x - 9.0): int, y: int, 5, 0xffffffff);
		viper::circle(win, (x + 9.0): int, y: int, 5, 0xffffffff);
		viper::circle(win, (x - 8.0): int, (y + 1.0): int, 2, 0xff101010);
		viper::circle(win, (x + 10.0): int, (y + 1.0): int, 2, 0xff101010);
	case 13 => // mahjong tiles
		for (let i = 1; i >= 0; i -= 1) {
			const ox = x - 14.0 + i: f64 * 18.0, oy = y - 4.0 - i: f64 * 6.0;
			viper::round_rect(win, (ox - 14.0): int, (oy - 20.0): int, 30, 42, 4, 0xff8a6a3a);
			viper::round_rect(win, (ox - 16.0): int, (oy - 22.0): int, 30, 40, 4, 0xfff4ecd8);
			viper::circle(win, (ox - 1.0): int, (oy - 8.0): int, 5, 0xffc83a3a);
			viper::circle(win, (ox - 1.0): int, (oy + 6.0): int, 5, 0xff3a8a4a);
		};
	case 14 => // gem
		tri(win, (x - 22.0, y - 6.0), (x + 22.0, y - 6.0), (x, y + 26.0), 0xff3ad8b8);
		const top: [4](f64, f64) = [(x - 12.0, y - 22.0), (x + 12.0, y - 22.0),
			(x + 22.0, y - 6.0), (x - 22.0, y - 6.0)];
		viper::polygon(win, top, 0xff8af0e0);
		tri(win, (x - 6.0, y - 6.0), (x + 6.0, y - 6.0), (x, y + 18.0), 0xff2ab8a0);
	case 15 => // a floppy disk (DOS)
		viper::round_rect(win, (x - 26.0): int, (y - 26.0): int, 52, 52, 4, 0xff3a3a5a);
		viper::rect(win, (x - 14.0): int, (y - 26.0): int, 28, 16, 0xffc8c8d0);
		viper::rect(win, (x + 4.0): int, (y - 23.0): int, 6, 10, 0xff3a3a5a);
		viper::rect(win, (x - 18.0): int, (y + 2.0): int, 36, 22, 0xfff4f4f4);
		viper::text(win, (x - 12.0): int, (y + 5.0): int, "DOS", 0xff3a3a5a);
	case 16 => // a castle wall
		for (let r = 0; r < 4; r += 1) for (let c = 0; c < 4; c += 1) {
			viper::rect(win, (x - 30.0): int + c * 15 + (r % 2) * 7, (y - 18.0): int + r * 11,
				13, 9, 0xff6a6a7a);
		};
		for (let c = 0; c < 4; c += 1) {
			viper::rect(win, (x - 30.0): int + c * 16, (y - 28.0): int, 9, 8, 0xff6a6a7a);
		};
		     viper::round_rect(win, (x - 8.0): int, (y + 4.0): int, 16, 22, 6, 0xff3a2a1a);
    case 17 => // golden pong: zebra stripes, two bats and a gold ball
		for (let s = 0; s < 8; s += 1) {
		const col: u32 = if (s % 2 == 0) 0xfff0f0f0 else 0xff1a1a1a;
		viper::rect(win, (x - 32.0): int + s * 8, (y - 24.0): int, 8, 48, col);
		};
		viper::rect(win, (x - 28.0): int, (y - 10.0): int, 5, 20, 0xffd83a3a);
		viper::rect(win, (x + 23.0): int, (y - 10.0): int, 5, 20, 0xffd83a3a);
		shine(win, x + math::sinf64(t * 2.0) * 14.0,
			y + math::cosf64(t * 3.0) * 10.0, 7, 0xffe0b030, 0xfffff2b0);
	case => void;
	};
};

// An original crocodile head for the arcade sign: long jaws and teeth.
fn draw_croc(win: *viper::window, x: f64, y: f64, s: f64, t: f64) void = {
	const open = (math::sinf64(t * 3.0) * 0.5 + 0.5) * 6.0 * s;
	const green: u32 = 0xff3a9a4a, dark: u32 = 0xff1e6a2e, belly: u32 = 0xffc8e08a;
	// Upper jaw and head.
	const up: [5](f64, f64) = [(x - 30.0 * s, y - 14.0 * s), (x + 10.0 * s, y - 18.0 * s),
		(x + 44.0 * s, y - 8.0 * s - open), (x + 44.0 * s, y - open), (x - 30.0 * s, y + 2.0 * s)];
	viper::polygon(win, up, green);
	// Lower jaw.
	const lo: [4](f64, f64) = [(x - 30.0 * s, y + 4.0 * s), (x + 42.0 * s, y + 4.0 * s + open),
		(x + 40.0 * s, y + 10.0 * s + open), (x - 30.0 * s, y + 14.0 * s)];
	viper::polygon(win, lo, belly);
	// Teeth.
	for (let i = 0; i < 6; i += 1) {
		const tx = x - 14.0 * s + i: f64 * 9.0 * s;
		tri(win, (tx, y - open * (i: f64 / 6.0)), (tx + 4.0 * s, y - open * (i: f64 / 6.0)),
			(tx + 2.0 * s, y + 5.0 * s), 0xffffffff);
	};
	// Eye bump with a gold eye, and a nostril.
	viper::circle(win, (x - 14.0 * s): int, (y - 18.0 * s): int, (9.0 * s): int, green);
	viper::circle(win, (x - 13.0 * s): int, (y - 19.0 * s): int, (5.0 * s): int, 0xffffd23a);
	viper::rect(win, (x - 13.0 * s): int, (y - 23.0 * s): int, (2.0 * s): int + 1, (8.0 * s): int, 0xff101010);
	viper::circle(win, (x + 38.0 * s): int, (y - 10.0 * s - open): int, (2.0 * s): int + 1, dark);
	// Scales along the back.
	for (let i = 0; i < 4; i += 1) {
		const sx = x - 26.0 * s + i: f64 * 9.0 * s;
		tri(win, (sx, y - 14.0 * s), (sx + 4.0 * s, y - 21.0 * s), (sx + 8.0 * s, y - 15.0 * s), dark);
	};
};
