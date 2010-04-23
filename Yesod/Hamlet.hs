{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE QuasiQuotes #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Yesod.Hamlet
    ( -- * Hamlet library
      Hamlet
    , hamlet
    , HtmlContent (..)
      -- * Convert to something displayable
    , hamletToContent
    , hamletToRepHtml
      -- * Page templates
    , PageContent (..)
      -- * data-object
    , HtmlObject
    )
    where

import Text.Hamlet
import Text.Hamlet.Monad (outputHtml)
import Yesod.Content
import Yesod.Handler
import Yesod.Definitions
import Data.Convertible.Text
import Data.Object
import Control.Arrow ((***))

-- | Content for a web page. By providing this datatype, we can easily create
-- generic site templates, which would have the type signature:
--
-- > PageContent url -> Hamlet url IO ()
data PageContent url = PageContent
    { pageTitle :: HtmlContent
    , pageHead :: Hamlet url IO ()
    , pageBody :: Hamlet url IO ()
    }

-- FIXME some typeclasses for the stuff below?
-- | Converts the given Hamlet template into 'Content', which can be used in a
-- Yesod 'Response'.
hamletToContent :: Hamlet (Routes master) IO () -> GHandler sub master Content
hamletToContent h = do
    render <- getUrlRenderMaster
    return $ ContentEnum $ go render
  where
    go render iter seed = do
        res <- runHamlet h render seed $ iter' iter
        case res of
            Left x -> return $ Left x
            Right ((), x) -> return $ Right x
    iter' iter seed text = iter seed $ cs text

-- | Wraps the 'Content' generated by 'hamletToContent' in a 'RepHtml'.
hamletToRepHtml :: Hamlet (Routes master) IO () -> GHandler sub master RepHtml
hamletToRepHtml = fmap RepHtml . hamletToContent

instance Monad m => ConvertSuccess String (Hamlet url m ()) where
    convertSuccess = outputHtml . Unencoded . cs
instance Monad m
    => ConvertSuccess (Object String HtmlContent) (Hamlet url m ()) where
    convertSuccess (Scalar h) = outputHtml h
    convertSuccess (Sequence s) = template () where
        template = [$hamlet|
                %ul
                    $forall s' s
                        %li ^s^|]
        s' _ = map cs s
    convertSuccess (Mapping m) = template () where
        template :: Monad m => () -> Hamlet url m ()
        template = [$hamlet|
                %dl
                    $forall pairs pair
                        %dt $pair.fst$
                        %dd ^pair.snd^|]
        pairs _ = map (cs *** cs) m
instance ConvertSuccess String HtmlContent where
    convertSuccess = Unencoded . cs

type HtmlObject = Object String HtmlContent

instance ConvertSuccess (Object String String) HtmlObject where
    convertSuccess = fmap cs
