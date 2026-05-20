import LandingExperience from "./LandingExperience";
import { releaseConfig } from "../src/server/env";

export default function Page() {
  let githubUrl: string | undefined;
  try {
    githubUrl = releaseConfig().githubUrl;
  } catch {
    githubUrl = process.env.WHOORDAN_GITHUB_URL;
  }
  return <LandingExperience githubUrl={githubUrl} />;
}
