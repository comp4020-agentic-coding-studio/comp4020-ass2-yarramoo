import { existsSync, readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

interface ApiNode {
  id: string;
  type: string;
  meta?: Record<string, unknown>;
}

interface CourseApi {
  course: { code: string };
  nodes: ApiNode[];
}

const api = JSON.parse(readFileSync(resolve("dist/api/index.json"), "utf8")) as CourseApi;
const nodesOfType = (type: string) => api.nodes.filter((node) => node.type === type);

// The three digits this repo was provisioned with — assigned once, kept
// forever. Only the level digit in front of them is ours to choose.
const PROVISIONED_DIGITS = "753";

describe("course coherence (assignment 2 spec)", () => {
  it("keeps the SLOP code's provisioned three digits", () => {
    expect(api.course.code).toMatch(new RegExp(`^SLOP[123468]${PROVISIONED_DIGITS}$`));
  });

  it("runs across all twelve dated teaching weeks", () => {
    const dated = [...nodesOfType("sessions"), ...nodesOfType("lectures")];
    const weeks = new Set(dated.map((node) => node.meta?.week));
    for (let week = 1; week <= 12; week += 1) {
      expect(weeks.has(week), `no session or lecture is dated in week ${week}`).toBe(true);
    }
  });

  it("has at least one lecture with a real, existing deck", () => {
    const lecturesWithSlides = nodesOfType("lectures").filter(
      (node) => typeof node.meta?.slides === "string",
    );
    expect(lecturesWithSlides.length, "no lecture links a deck via `slides:`").toBeGreaterThan(0);

    for (const lecture of lecturesWithSlides) {
      const slug = String(lecture.meta?.slides).replace(/^\/decks\//, "").replace(/\/$/, "");
      const deckPath = resolve(`src/decks/${slug}.deck.mdx`);
      expect(existsSync(deckPath), `${lecture.id} links a deck at ${slug} that doesn't exist`).toBe(
        true,
      );
    }
  });

  it("assessment weights add up to 100%", () => {
    const total = nodesOfType("assessments").reduce(
      (sum, node) => sum + Number(node.meta?.weight ?? 0),
      0,
    );
    expect(total).toBe(100);
  });
});

// Two invariants recovered from real coherence bugs. Neither is the kind of
// thing `pnpm build` can see: both were true statements about a page sitting
// next to a codebase that did something else, which renders perfectly.
const walk = (dir: string, out: string[] = []): string[] => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    if (entry.isDirectory()) walk(path, out);
    else if (/\.(md|mdx)$/.test(entry.name)) out.push(path);
  }
  return out;
};

describe("pages agree with the code they describe", () => {
  // week-01 told students to reach for `ocamllex` while every shipped week
  // hand-rolls its lexer, for SNOBOL4's blank-sensitivity rule. Fixed across
  // three pages, and then again 54 minutes later when the week-1 deck turned
  // out to still say it. A page may name `ocamllex` -- to contrast with it, or
  // to cite the manual's chapter -- but never without saying what this course
  // actually does, which is the half the first fix missed.
  it("never names ocamllex on a page that doesn't also say hand-rolled", () => {
    const offenders = walk("src")
      .filter((path) => /ocamllex/.test(readFileSync(path, "utf8")))
      .filter((path) => !/hand-rolled/i.test(readFileSync(path, "utf8")));
    expect(
      offenders,
      `these pages mention ocamllex without saying the course hand-rolls its lexer: ${offenders.join(", ")}`,
    ).toHaveLength(0);
  });

  // Three pages promised "all seven Movement III primitives" while
  // interpreter/README.md's scope notes said ARBNO and BAL had been dropped.
  // The promise is the contract; this checks the reference implementation
  // keeps it, and that the README hasn't quietly re-scoped one back out.
  const MOVEMENT_III = ["LEN", "ANY", "NOTANY", "SPAN", "BREAK", "ARB", "ARBNO"];

  it("implements every Movement III primitive the pages promise", () => {
    const dir = "interpreter/checkpoint-3/lib";
    const sources = readdirSync(dir).filter((name) => name.endsWith(".ml"));
    expect(sources.length, `no OCaml sources under ${dir}`).toBeGreaterThan(0);
    const lib = sources.map((name) => readFileSync(`${dir}/${name}`, "utf8")).join("\n");
    for (const primitive of MOVEMENT_III) {
      expect(
        new RegExp(`\\b${primitive}\\b`).test(lib),
        `pages promise all seven Movement III primitives, but ${primitive} isn't in checkpoint-3's implementation`,
      ).toBe(true);
    }
  });

  it("doesn't list a promised primitive as out of scope", () => {
    const readme = readFileSync("interpreter/README.md", "utf8");
    const scope = readme.match(/[^.]*still out of scope[^.]*\./s)?.[0] ?? "";
    for (const primitive of MOVEMENT_III) {
      expect(
        new RegExp(`\`${primitive}\``).test(scope),
        `${primitive} is promised on the course pages but listed out of scope in interpreter/README.md`,
      ).toBe(false);
    }
  });
});
