///|
pub extend MdfError with @debug.Debug::{to_repr}

///|
pub extend MdfError with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend RawValue with @debug.Debug::{to_repr}

///|
pub extend RawValue with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Channel with @debug.Debug::{to_repr}

///|
pub extend Series with @debug.Debug::{to_repr}

///|
pub extend Interpolation with @debug.Debug::{to_repr}

///|
pub extend Interpolation with Eq::{equal, not_equal}

///|
pub extend Conversion with @debug.Debug::{to_repr}
