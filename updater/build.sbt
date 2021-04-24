enablePlugins(NativeImagePlugin)

name := "jetbrains-updater"

scalaVersion := "3.0.0-RC1"

scalacOptions ++= Seq(
  "-explain",
  "-feature",
  "-new-syntax",
  "-release", "11",
  "-unchecked",

  "-Ycheck-init",

  "-Xverify-signatures",
)

libraryDependencies ++= Seq(
  "org.scala-lang.modules" %% "scala-xml" % "2.0.0-M5",
  "org.typelevel" %% "cats-effect" % "3.0.0-RC2",
  "io.circe" %% "circe-core" % "0.14.0-M4",
  "io.circe" %% "circe-jawn" % "0.14.0-M4",
  "io.circe" %% "circe-generic" % "0.14.0-M4",
  "org.slf4j" % "slf4j-simple" % "1.7.30" % Runtime,
  "org.http4s" %% "http4s-scala-xml" % "1.0.0-M19",
  "org.http4s" %% "http4s-circe" % "1.0.0-M19",
  "org.http4s" %% "http4s-blaze-client" % "1.0.0-M19",
)

ThisBuild / resolvers += Resolver.JCenterRepository

nativeImageOptions ++= Seq(
  "--no-fallback",
  "-H:+ReportExceptionStackTraces",
  "-H:+AddAllCharsets",
  "--enable-http",
  "--enable-https",
  "--enable-all-security-services",
  "--allow-incomplete-classpath",
  "-Dorg.slf4j.simpleLogger.defaultLogLevel=trace",
  s"-Dsun.java.command=${name.value}",
  "--initialize-at-build-time",
  "--initialize-at-run-time=updater.Main$",
)