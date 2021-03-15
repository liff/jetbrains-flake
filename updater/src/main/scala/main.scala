package updater

import java.nio.file.{NoSuchFileException, Path}

import cats.data.OptionT
import cats.effect.{ExitCode, IO, IOApp}
import cats.effect.std.Console
import cats.syntax.all._
import io.circe.DecodingFailure
import org.http4s.Method.GET
import org.http4s.client.blaze.BlazeClientBuilder
import org.http4s.client.dsl.io._

import formats.updates.given

object Main extends IOApp:
  private def httpClient =
    BlazeClientBuilder[IO](scala.concurrent.ExecutionContext.global).resource

  override def run(args: List[String]): IO[ExitCode] =
    args.match
      case state :: Nil => (pathOf[IO](state) >>= update).as(ExitCode.Success)
      case _ =>
        for _ <- Console[IO].errorln(s"Usage: jetbrains-updater STATE-FILE") 
        yield ExitCode.Error
  
  private def update(state: Path): IO[Unit] =
    httpClient.use { http =>
      for
        current <- readJsonFile[IO, Packages](state).recover {
          case _: (NoSuchFileException | DecodingFailure) => Packages.empty
        }

        products <- http.expect[List[Product]](updates)

        packages <- {
          def resolve(product: String, edition: Edition, status: Status, variant: Variant, build: Build) =
            val known = current.findArtifact(product, edition, status, variant, build).toOptionT[IO]

            val resolved = (for
               downloadUri <- downloadUriFor(product, edition, status, variant, build).toOptionT[IO]
               checksum <- OptionT(http.expectOption[Checksum](GET(downloadUri % "sha256")))
             yield Artifact(build, downloadUri, checksum))

            known.orElse(resolved).value

          products.collected { case Product(product, _, channels) =>
            product -*> Edition.all.collected { edition =>
              edition -*> channels.parCollected { case Channel(_, _, _, status, _, builds) =>
                status -*> Variant.all.collected { variant =>
                  variant -*> builds.parTraverse(resolve(product, edition, status, variant, _)).map(_.toList.unite)
                }
              }
            }
          }
        }

        _ <- writeJsonFile[IO, Packages](state, packages)

      yield ()
    }
