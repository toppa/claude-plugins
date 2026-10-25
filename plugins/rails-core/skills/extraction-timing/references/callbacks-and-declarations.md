# Why each callback decision goes the way it does

The rule and the job-by-job table are in `SKILL.md`, section "Callbacks vs explicit calls". This file holds
the mechanism behind each row. Verified against rails 8.1.3.1.

**`normalizes`, rather than a hand-written `before_validation`.** `normalizes` registers a
`before_validation` for you (`activemodel-8.1.3.1/lib/active_model/attributes/normalization.rb:8-15`), so
uniqueness and format validate the value you will actually store. The 8.1 authentication generator writes
this exact line into `User`. The save sequence is why normalization is declared rather than hooked:
`before_validation` runs first, then `validate`, and only then `before_save`
(`activerecord-8.1.3.1/lib/active_record/callbacks.rb:14-22`) — so normalization has to land before
validation, which is precisely what `normalizes` guarantees.

**A column default or `attribute … default:`, rather than `after_initialize`.** The default belongs to the
attribute (`activerecord-8.1.3.1/lib/active_record/attributes.rb:38-44,82-104`), so it applies when the
object is built and costs nothing on read. `after_initialize` fires for every object a finder instantiates,
not only for `new` (`active_record/callbacks.rb:31-33`), so defaults placed there run again on every loaded
row.

**A destroy guard is the one non-normalization callback worth keeping.** It has to run inside the same
transaction as the delete, so a caller cannot skip it.

**Mail, jobs, external API calls and related records with business logic are explicit calls.** Each one
fails, retries, and has an order relative to the others. Called explicitly from a service, the sequence is
visible to its caller and absent from tests and fixtures that only wanted a record.
