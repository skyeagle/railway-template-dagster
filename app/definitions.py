from datetime import UTC, datetime

from dagster import (
    AssetExecutionContext,
    Definitions,
    MaterializeResult,
    ScheduleDefinition,
    asset,
    define_asset_job,
    in_process_executor,
)


@asset(
    description="Builds a deterministic daily order summary for the starter project.",
    group_name="starter",
)
def daily_order_summary(context: AssetExecutionContext) -> MaterializeResult:
    orders = (
        {"region": "north", "amount": 125},
        {"region": "south", "amount": 80},
        {"region": "north", "amount": 45},
    )
    total_revenue = sum(order["amount"] for order in orders)
    context.log.info("Processed %s sample orders", len(orders))

    return MaterializeResult(
        metadata={
            "order_count": len(orders),
            "total_revenue_usd": total_revenue,
            "generated_at": datetime.now(UTC).isoformat(),
        }
    )


daily_metrics_job = define_asset_job(
    "daily_metrics_job",
    selection=[daily_order_summary],
    executor_def=in_process_executor,
)

daily_metrics_schedule = ScheduleDefinition(
    job=daily_metrics_job,
    cron_schedule="0 6 * * *",
    execution_timezone="UTC",
)

defs = Definitions(
    assets=[daily_order_summary],
    jobs=[daily_metrics_job],
    schedules=[daily_metrics_schedule],
)
