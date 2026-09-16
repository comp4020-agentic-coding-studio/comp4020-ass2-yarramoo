import { existsSync, readFileSync } from "node:fs";
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
