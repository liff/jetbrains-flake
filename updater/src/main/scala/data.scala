package updater

import java.time.LocalDate
import java.util.Locale

import cats.data.{NonEmptyList, NonEmptySet, NonEmptyVector}
import cats.effect.Concurrent
import cats.syntax.all._
import cats.{Eq, Order, Show}
import io.circe.generic.semiauto.{deriveCodec, deriveDecoder, deriveEncoder}
import io.circe.syntax._
import io.circe.{Codec, Decoder, Encoder, JsonObject, KeyDecoder, KeyEncoder}
import org.http4s.circe._
import org.http4s.{EntityDecoder, Uri}


def lowerCase[A: Show](a: A) = a.show.toLowerCase(Locale.ROOT).nn

abstract class EnumCompanion[A <: scala.reflect.Enum]:
  def valueOf(str: String): A
  def values: Array[A]

  final lazy val all: NonEmptyVector[A] = NonEmptyVector.fromVectorUnsafe(values.toVector)
  given Show[A] = Show.fromToString
  given Order[A] = Order.by(_.ordinal)
  given Encoder[A] = Encoder[String].contramap(lowerCase)
  given Decoder[A] = Decoder[String].emap { str =>
    fromString(str).toRight(s"Unrecognized enumeration value $str")
  }
  given KeyEncoder[A] = KeyEncoder[String].contramap(lowerCase)
  given KeyDecoder[A] = KeyDecoder.instance(fromString)
  given CanEqual[A, A] = CanEqual.derived

  def fromString(str: String): Option[A] =
    try Some(valueOf(str.capitalize)) catch case _: IllegalArgumentException => None


enum Edition derives CanEqual { case Licensed, Community }
object Edition extends EnumCompanion[Edition]


enum Status derives CanEqual{ case Release, Eap }
object Status extends EnumCompanion[Status]


enum Licensing derives CanEqual { case Release, Eap }
object Licensing extends EnumCompanion[Licensing]


enum Distribution derives CanEqual { case Default, NoJbr }
object Distribution extends EnumCompanion[Distribution]


case class Build(number: String, version: String, releaseDate: Option[LocalDate], fullNumber: Option[String])
  derives CanEqual {
  
  val fullNumbers: Option[List[Int]] = fullNumber.flatMap(_.split('.').toList.traverse(_.toIntOption))

  val numbers: Option[List[Int]] = number.split('.').toList.traverse(_.toIntOption) 
}

object Build:
  given Codec.AsObject[Build] = deriveCodec
  given Order[Build] =
    Order.whenEqual(
      Order.by(_.fullNumbers),
      Order.whenEqual(
        Order.by(_.numbers),
        Order.whenEqual(
          Order.by(_.version),
          Order.by(_.releaseDate))))

case class Channel(id: String, name: String, majorVersion: String, status: Status, licensing: Licensing, builds: NonEmptyList[Build])
  derives CanEqual

object Channel:
  given Codec.AsObject[Channel] = deriveCodec


case class Product(name: String, codes: NonEmptySet[String], channels: NonEmptyList[Channel])
  derives CanEqual

object Product:
  given Codec[Product] = deriveCodec


opaque type Sha256 = String

object Sha256:
  given Order[Sha256] = Order.from((a, b) => a.compareTo(b))
  given Encoder[Sha256] = Encoder.encodeString
  given Decoder[Sha256] = Decoder.decodeString
  given [F[_]: Concurrent]: EntityDecoder[F, Sha256] =
    EntityDecoder.text[F].map(_.takeWhile(_ != ' '))


case class Artifact(build: Build, downloadUri: Uri, sha256: Sha256)
  derives CanEqual

object Artifact:
  given Order[Artifact] =
    Order.whenEqual(
      Order.by(_.build),
      Order.whenEqual(
        Order.by(_.downloadUri),
        Order.by(_.sha256)))
  given Encoder.AsObject[Artifact] = Encoder.AsObject.instance { case Artifact(build, downloadUri, sha256) =>
    JsonObject("build" := build, "downloadUri" := downloadUri, "sha256" := sha256)
  }
  given Decoder[Artifact] = Decoder.instance { c =>
    (c.get[Build]("build"), c.get[Uri]("downloadUri"), c.get[Sha256]("sha256")).mapN(Artifact.apply)
  }


type Packages = Map[String, Map[Edition, Map[Status, Map[Distribution, List[Artifact]]]]]

object Packages:
  val empty: Packages = Map.empty

extension (packages: Packages)
  def findArtifact(product: String, edition: Edition, status: Status, distribution: Distribution, build: Build): Option[Artifact] =
    packages
      .get(product)
      .flatMap(_.get(edition))
      .flatMap(_.get(status))
      .flatMap(_.get(distribution))
      .flatMap(_.find(_.build == build))
