package updater

import java.nio.file.Path

import cats.syntax.all._
import cats.{Eq, Foldable, Functor, Monad, Monoid, Parallel, Traverse}
import org.http4s.Uri


extension [F[_]: Foldable, A, B: Monoid: Eq](xs: F[(A, B)])
  def smush: Map[A, B] =
    xs.filter_(!_._2.isEmpty).map((k, v) => Map(k -> v)).combineAll

extension [T[_]: Traverse, A](xs: T[A])
  def parCollected[M[_]: Monad: Parallel, B, C: Monoid: Eq](f: A => M[(B, C)]): M[Map[B, C]] =
    xs.parTraverse(f).map(_.smush)

  def collected[M[_]: Monad, B, C: Monoid: Eq](f: A => M[(B, C)]): M[Map[B, C]] =
    xs.traverse(f).map(_.smush)

extension [A](a: A)
  def -*>[F[_]: Functor, B](fb: F[B]): F[(A, B)] = fb.map(a -> _)

extension (path: Uri.Path)
  def withFileExtension(ext: String): Uri.Path =
    if path.endsWithSlash || path.isEmpty then path else
      val init = path.segments.dropRight(1)
      path.segments.lastOption.map { last =>
        Uri.Path(
          segments = init :+ Uri.Path.Segment(last.encoded ++ s".$ext"),
          absolute = path.absolute,
          endsWithSlash = path.endsWithSlash)
      }.getOrElse(path)

extension (uri: Uri)
  def %(ext: String): Uri = uri.withPath(uri.path.withFileExtension(ext))
