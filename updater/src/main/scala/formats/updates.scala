package updater
package formats
package updates

import java.time.LocalDate
import java.time.format.DateTimeFormatter.BASIC_ISO_DATE
import java.time.format.DateTimeParseException

import cats.data.{Nested, NonEmptyList, NonEmptySet, OptionT, ValidatedNel}
import cats.effect.Concurrent
import cats.syntax.all._
import org.http4s.scalaxml.implicits._
import org.http4s.{DecodeResult, EntityDecoder, InvalidMessageBodyFailure}

import scala.collection.immutable.SortedSet
import scala.xml.{Elem, Node, NodeSeq}


type Result[A] = ValidatedNel[String, A]

final case class DecodingFailures(messages: NonEmptyList[String])
  extends Exception(messages.toList.mkString("\n"))

def parseBasicIso(str: String): Result[LocalDate] =
  try LocalDate.parse(str, BASIC_ISO_DATE).nn.valid
  catch case e: DateTimeParseException => {
    val msg = e.getMessage
    if msg == null then "failed to parse" else msg
  }.invalidNel

extension (nodes: NodeSeq)
  def some(that: String): Result[NonEmptyList[Node]] =
    NonEmptyList
      .fromList((nodes \ that).toList)
      .toValidNel(s"Projection $that does not match any nodes in $nodes")

  def one(that: String): Result[Node] =
    some(that).map(_.head)

  def maybeOne(that: String): Result[Option[Node]] =
    (nodes \ that).match
      case first +: _ => Some(first).valid
      case _ => none.valid

  def attr(name: String): Result[String] =
    one(s"@$name").map(_.text)
    
  def maybeAttr(name: String): Result[Option[String]] =
    Nested(maybeOne(s"@$name")).map(_.text).value
    
  def nonEmptyAttr(name: String): Result[String] =
    attr(name).andThen { content =>
      if content.isEmpty
      then s"Expected non-empty value for attribute '$name'".invalidNel
      else content.valid
    }

def build(node: Node): Result[Build] =
  (node.attr("number"),
    node.nonEmptyAttr("version"),
    node.maybeAttr("releaseDate").andThen(_.traverse(parseBasicIso)),
    node.maybeAttr("fullNumber")).mapN(Build.apply)

def channel(node: Node): Result[Channel] =
  (node.attr("id"), 
    node.nonEmptyAttr("name"),
    node.attr("majorVersion"),
    node.attr("status").andThen(str => Status.fromString(str).toValidNel("Unrecognized Status")),
    node.attr("licensing").andThen(str => Licensing.fromString(str).toValidNel("Unrecognized Licensing")),
    node.some("build").andThen(_.traverse(build))).mapN(Channel.apply)

def product(node: Node): Result[Product] =
  (node.nonEmptyAttr("name"),
   node.some("code").map(_.map(_.text).toNes),
   node.some("channel").andThen(_.traverse(channel))).mapN(Product.apply)

given [F[_]: Concurrent]: EntityDecoder[F, List[Product]] =
  EntityDecoder[F, Elem].flatMapR { elem =>
    (elem \ "product").toList.traverse(product).fold(messages => DecodeResult.failureT(InvalidMessageBodyFailure("Failed to decode products XML", Some(DecodingFailures(messages)))), DecodeResult.successT)
  }
