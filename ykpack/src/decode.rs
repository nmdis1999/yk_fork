use crate::Pack;
use fallible_iterator::FallibleIterator;
use rmp_serde::{
    decode::{self, ReadReader},
    Deserializer,
};
use serde::Deserialize;
use std::io::Read;

/// The pack decoder.
/// Offers a simple iterator interface to serialised packs.
pub struct Decoder<'a> {
    deser: Deserializer<ReadReader<&'a mut dyn Read>>,
}

impl<'a> Decoder<'a> {
    /// Returns a new decoder which will deserialise from `read_from`.
    pub fn from(read_from: &'a mut dyn Read) -> Self {
        let deser = Deserializer::new(read_from);
        Self { deser }
    }
}

impl<'a> FallibleIterator for Decoder<'a> {
    type Item = Pack;
    type Error = decode::Error;

    fn next(&mut self) -> Result<Option<Self::Item>, Self::Error> {
        Option::<Pack>::deserialize(&mut self.deser)
    }
}
