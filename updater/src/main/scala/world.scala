package updater

import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.{InvalidPathException, Path}
import java.nio.file.StandardOpenOption.{CREATE, TRUNCATE_EXISTING}
import java.time.LocalDate

import cats.effect.{Async, Sync}
import cats.Order
import cats.syntax.all._
import cats.ApplicativeError
import fs2.Stream
import fs2.io.file.Files
import fs2.text.utf8Encode
import io.circe.jawn.decodeByteBuffer
import io.circe.syntax._
import io.circe.{Decoder, Encoder, Printer}
import scodec.bits.ByteVector


def readJsonFile[F[_]: Async, A: Decoder](path: Path): F[A] =
  Files[F].readAll(path, 1024*1024)
    .compile
    .to(ByteVector)
    .map(_.toByteBuffer)
    .map(decodeByteBuffer)
    .flatMap(Async[F].fromEither)

def writeJsonFile[F[_]: Async, A: Encoder](path: Path, a: A): F[Unit] =
  Stream
    .emit(a.asJson.spaces4)
    .through(utf8Encode)
    .through(Files[F].writeAll(path, Seq(CREATE, TRUNCATE_EXISTING)))
    .compile
    .drain

def pathOf[F[_]](str: String)(using F: ApplicativeError[F, Throwable]): F[Path] =
  F.catchOnly[InvalidPathException](Path.of(str).nn)

given Order[LocalDate] = Order.from((a, b) => a.compareTo(b))