import {
  defineRailway,
  github,
  group,
  postgres,
  project,
  service,
} from "railway/iac";

const SOURCE = github("skyeagle/railway-template-dagster", {
  branch: "railway-template-v1",
  rootDirectory: "/",
});

export default defineRailway(() => {
  const database = postgres("PostgreSQL");

  const webserver = service("Dagster Webserver", {
    source: SOURCE,
    start: "./scripts/start.sh webserver",
    healthcheck: "/server_info",
    healthcheckTimeout: 300,
    env: {
      DAGSTER_HOME: "/opt/dagster/dagster_home",
      DATABASE_URL: database.env.DATABASE_URL,
      PORT: "3000",
    },
  });

  const daemon = service("Dagster Daemon", {
    source: SOURCE,
    start: "./scripts/start.sh daemon",
    healthcheck: "/health",
    healthcheckTimeout: 300,
    env: {
      DAGSTER_HOME: "/opt/dagster/dagster_home",
      DATABASE_URL: database.env.DATABASE_URL,
      PORT: "3001",
    },
  });

  return project("Dagster", {
    resources: [
      group("Application", [webserver, daemon]),
      group("Data", [database]),
    ],
  });
});
