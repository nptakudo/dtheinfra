import sbt._
import Keys._

ThisBuild / scalaVersion := "2.12.18"
ThisBuild / organization := "com.dataplatform"
ThisBuild / version := "0.1.0-SNAPSHOT"

// Shared settings for all projects
lazy val commonSettings = Seq(
  libraryDependencies ++= Seq(
    "org.scalatest" %% "scalatest" % "3.2.17" % Test,
    "org.scalamock" %% "scalamock" % "5.2.0" % Test,
    "ch.qos.logback" % "logback-classic" % "1.4.14"
  ),
  scalacOptions ++= Seq(
    "-deprecation",
    "-feature",
    "-unchecked",
    "-Xfatal-warnings",
    "-Ywarn-unused:imports"
  ),
  Test / fork := true,
  Test / parallelExecution := false
)

// Version constants
val sparkVersion = "3.5.0"
val icebergVersion = "1.4.3"
val flinkVersion = "1.18.1"
val kafkaVersion = "3.6.1"

// Root project
lazy val root = (project in file("."))
  .aggregate(
    sparkUtils,
    flinkUtils,
    icebergUtils,
    etlBronze,
    etlSilver,
    etlGold,
    realtimeAggregator,
    eventEnricher
  )
  .settings(
    name := "data-platform",
    publish / skip := true
  )

// ========== Shared Libraries ==========

lazy val sparkUtils = (project in file("libs/scala/spark-utils"))
  .settings(commonSettings)
  .settings(
    name := "spark-utils",
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % sparkVersion % Provided,
      "org.apache.spark" %% "spark-sql" % sparkVersion % Provided,
      "org.apache.spark" %% "spark-hive" % sparkVersion % Provided,
      "org.apache.iceberg" %% "iceberg-spark-runtime-3.5" % icebergVersion
    )
  )

lazy val flinkUtils = (project in file("libs/scala/flink-utils"))
  .settings(commonSettings)
  .settings(
    name := "flink-utils",
    libraryDependencies ++= Seq(
      "org.apache.flink" %% "flink-scala" % flinkVersion % Provided,
      "org.apache.flink" %% "flink-streaming-scala" % flinkVersion % Provided,
      "org.apache.flink" % "flink-connector-kafka" % flinkVersion,
      "org.apache.flink" % "flink-avro" % flinkVersion,
      "org.apache.flink" % "flink-json" % flinkVersion
    )
  )

lazy val icebergUtils = (project in file("libs/scala/iceberg-utils"))
  .settings(commonSettings)
  .settings(
    name := "iceberg-utils",
    libraryDependencies ++= Seq(
      "org.apache.iceberg" % "iceberg-core" % icebergVersion,
      "org.apache.iceberg" % "iceberg-aws" % icebergVersion,
      "org.apache.iceberg" % "iceberg-parquet" % icebergVersion,
      "software.amazon.awssdk" % "glue" % "2.21.0",
      "software.amazon.awssdk" % "s3" % "2.21.0"
    )
  )

// ========== Spark Jobs ==========

lazy val etlBronze = (project in file("apps/processing/spark-jobs/etl-bronze"))
  .dependsOn(sparkUtils, icebergUtils)
  .settings(commonSettings)
  .settings(
    name := "etl-bronze",
    assembly / mainClass := Some("com.dataplatform.etl.bronze.Main"),
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", xs @ _*) => MergeStrategy.discard
      case "reference.conf" => MergeStrategy.concat
      case x => MergeStrategy.first
    }
  )

lazy val etlSilver = (project in file("apps/processing/spark-jobs/etl-silver"))
  .dependsOn(sparkUtils, icebergUtils)
  .settings(commonSettings)
  .settings(
    name := "etl-silver",
    assembly / mainClass := Some("com.dataplatform.etl.silver.Main")
  )

lazy val etlGold = (project in file("apps/processing/spark-jobs/etl-gold"))
  .dependsOn(sparkUtils, icebergUtils)
  .settings(commonSettings)
  .settings(
    name := "etl-gold",
    assembly / mainClass := Some("com.dataplatform.etl.gold.Main")
  )

// ========== Flink Jobs ==========

lazy val realtimeAggregator = (project in file("apps/processing/flink-jobs/realtime-aggregator"))
  .dependsOn(flinkUtils)
  .settings(commonSettings)
  .settings(
    name := "realtime-aggregator",
    assembly / mainClass := Some("com.dataplatform.streaming.aggregator.Main")
  )

lazy val eventEnricher = (project in file("apps/processing/flink-jobs/event-enricher"))
  .dependsOn(flinkUtils)
  .settings(commonSettings)
  .settings(
    name := "event-enricher",
    assembly / mainClass := Some("com.dataplatform.streaming.enricher.Main")
  )

// Assembly plugin settings
addCommandAlias("buildAll", ";clean;compile;test")
addCommandAlias("assemblyAll", ";clean;assembly")
