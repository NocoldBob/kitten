{-|
Module      : Kitten.Desugar.Data
Description : Desugaring data type constructors
Copyright   : (c) Jon Purdy, 2016
License     : MIT
Maintainer  : evincarofautumn@gmail.com
Stability   : experimental
Portability : GHC
-}

{-# LANGUAGE DataKinds #-}

module Kitten.Desugar.Data
  ( desugar
  ) where

import Data.List (foldl')
import Kitten.DataConstructor (DataConstructor)
import Kitten.Definition (Definition(Definition))
import Kitten.Entry.Parameter (Parameter(Parameter))
import Kitten.Fragment (Fragment)
import Kitten.Name (ConstructorIndex(..), GeneralName(..), Qualified(..))
import Kitten.Origin (getOrigin)
import Kitten.Phase (Phase(..))
import Kitten.Term (Sweet(..))
import Kitten.TypeDefinition (TypeDefinition)
import qualified Kitten.DataConstructor as DataConstructor
import qualified Kitten.Definition as Definition
import qualified Kitten.Entry.Category as Category
import qualified Kitten.Entry.Merge as Merge
import qualified Kitten.Entry.Parent as Parent
import qualified Kitten.Fragment as Fragment
import qualified Kitten.Operator as Operator
import qualified Kitten.Signature as Signature
import qualified Kitten.TypeDefinition as TypeDefinition

-- | Desugars data type constructors into word definitions, e.g.:
--
-- > type Optional<T>:
-- >   case none
-- >   case some (T)
-- >
-- > // =>
-- >
-- > define none<T> (-> Optional<T>) { ... }
-- > define some<T> (T -> Optional<T>) { ... }

desugar :: Fragment 'Parsed -> Fragment 'Parsed
desugar fragment = fragment
  { Fragment.definitions = Fragment.definitions fragment
    ++ concatMap desugarTypeDefinition (Fragment.types fragment) }

desugarTypeDefinition :: TypeDefinition -> [Definition 'Parsed]
desugarTypeDefinition definition
  = zipWith (desugarConstructor definition) [0..]
  $ TypeDefinition.constructors definition

desugarConstructor :: TypeDefinition -> Int -> DataConstructor -> Definition 'Parsed
desugarConstructor definition index constructor = Definition
  { Definition.body = STag () (getOrigin constructor)
    (length $ DataConstructor.fields constructor)
    (ConstructorIndex index)
  , Definition.category = Category.Constructor
  , Definition.fixity = Operator.Postfix
  , Definition.inferSignature = False
  , Definition.merge = Merge.Deny
  , Definition.name = Qualified qualifier
    $ DataConstructor.name constructor
  , Definition.origin = origin
  , Definition.parent = Just $ Parent.Type
    $ TypeDefinition.name definition
  , Definition.signature = constructorSignature
  }
  where
  resultSignature = foldl'
    (\ a b -> Signature.Application a b origin)
    (Signature.Variable (QualifiedName $ TypeDefinition.name definition)
      $ TypeDefinition.origin definition)
    $ map (\ (Parameter parameterOrigin parameter _kind)
      -> Signature.Variable (UnqualifiedName parameter) parameterOrigin)
    $ TypeDefinition.parameters definition
  constructorSignature = Signature.Quantified
    (TypeDefinition.parameters definition)
    (Signature.Function
      (DataConstructor.fields constructor) [resultSignature] [] origin)
    origin
  origin = DataConstructor.origin constructor
  qualifier = qualifierName $ TypeDefinition.name definition
