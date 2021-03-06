# Analysis of the King James Bible

# I. Install packages and load data

library(bibler)
library(tidytext)
library(magrittr)
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(SnowballC)

data("king_james_df")
data(stop_words)

# IIi. Analyse book by characters

book_by_characters <- king_james_df %>% 
  group_by(Book = King.James.Bible, Testament) %>% 
  summarize(Characters = sum(nchar(Text))) %>% 
  arrange(desc(Characters))

book_by_characters$Book <- factor(book_by_characters$Book, levels = book_by_characters$Book[order(book_by_characters$Characters)]) # Reorder books according to length
book_by_characters$Testament <- factor(book_by_characters$Testament, levels = c("Old Testament", "New Testament"))

ggplot(book_by_characters, aes(Book, Characters, fill = Testament)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c(`Old Testament` = "#00BFC4", `New Testament` = "#F8766D")) +
  labs(titles = "Books of the King James Bible by character count") + 
  scale_y_continuous(expand = c(0, 0), label = comma)

old_length_characters <- sum(nchar(king_james_df$Text[king_james_df$Testament=="Old Testament"]))
new_length_characters <- sum(nchar(king_james_df$Text[king_james_df$Testament=="New Testament"]))

# IIii. Analyse book by words 

book_by_words <- king_james_df %>% 
  unnest_tokens(word, Text) %>% 
  count(Book = King.James.Bible, Testament, word, sort = TRUE) %>% 
  ungroup() %>%
  group_by(Book, Testament) %>% 
  summarize(Words = sum(n)) %>% 
  arrange(desc(Words))

book_by_words$Book <- factor(book_by_words$Book,
                             levels = book_by_words$Book[order(book_by_words$Words)]) # Reorder books according to length
book_by_words$Testament <- factor(book_by_words$Testament, levels = c("Old Testament", "New Testament"))

ggplot(book_by_words, aes(Book, Words, fill = Testament)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c(`Old Testament` = "#00BFC4", `New Testament` = "#F8766D")) +
  labs(titles = "Books of the King James Bible by word count") + 
  scale_y_continuous(expand = c(0, 0), label = comma)

old_length_words <- sum(book_by_words$Words[book_by_words$Testament=="Old Testament"])
new_length_words <- sum(book_by_words$Words[book_by_words$Testament=="New Testament"])

# III. Word frequencies: Old Testament vs New Testament 

tidy_bible <- king_james_df %>% 
  unnest_tokens(word, Text) %>% 
  anti_join(stop_words) %>% 
  anti_join(tibble(word = middle_english_stopwords)) %>% 
  mutate(word = wordStem(word))

total_frequency <- tidy_bible %>% 
  group_by(Testament) %>% 
  count(word, sort = TRUE) %>% 
  left_join(tidy_bible %>% 
              group_by(Testament) %>% 
              summarise(total = n())) %>% 
  mutate(freq = n/total) %>% 
  select(Testament, word, freq) %>% 
  spread(Testament, freq) %>% 
  arrange(`Old Testament`, `New Testament`)

ggplot(total_frequency, aes(`Old Testament`, `New Testament`, color = abs(`New Testament` - `Old Testament`))) +
  geom_jitter(alpha = 0.1, size = 2.5, width = 0.3, height = 0.3) +
  geom_text(aes(label = word), check_overlap = TRUE, vjust = 1.5) +
  scale_x_log10(labels = percent_format()) +
  scale_y_log10(labels = percent_format()) +
  geom_abline(color = "gray40", lty = 2) +
  scale_color_gradient(limits = c(0, 0.001), low = "darkslategray4", high = "gray75") +
  theme(legend.position="none") +
  labs(title = "Word frequencies in the Old and New Testament")

# IVi. Tf_idf: Testament-level

testament_count <- king_james_df %>% 
  unnest_tokens(word, Text) %>% 
  count(Testament, word, sort = TRUE) %>% 
  mutate(word = wordStem(word))

total_count <- testament_count %>% 
  group_by(Testament) %>% 
  summarize(total = sum(n))

testament_total_count <- left_join(testament_count, total_count)
testament_total_count <- testament_total_count %>% 
  bind_tf_idf(word, Testament, n)

testament_total_count$Testament <- factor(testament_total_count$Testament, levels = c("Old Testament", "New Testament"))

testament_total_count %>% 
  arrange(desc(tf_idf)) %>% 
  mutate(word = factor(word, levels = rev(unique(word)))) %>% 
  group_by(Testament) %>% 
  top_n(15) %>% 
  ungroup %>% 
  ggplot(aes(word, tf_idf, fill = Testament)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf") +
  facet_wrap(~Testament, ncol = 2, scales = "free") +
  coord_flip() +
  scale_fill_manual(values = c(`Old Testament` = "#00BFC4", `New Testament` = "#F8766D"))

# IVii. Tf_idf: Book-level (Old Testament)

formatter <- function(x) {
  lab <- gsub("(.* )?.* ", "", x)
}

old_testament <- king_james_df[king_james_df$Testament=="Old Testament",]

old_testament$factorfun <-  as.numeric(factor(king_james_df$King.James.Bible[king_james_df$Testament=="Old Testament"], levels = unique(king_james_df$King.James.Bible[king_james_df$Testament=="Old Testament"])))

old_testament$King.James.Bible <- factor(reorder(old_testament$King.James.Bible, old_testament$factorfun))

book_count <- old_testament %>% 
  unnest_tokens(word, Text) %>% 
  count(Book = King.James.Bible, word, sort = TRUE) %>% 
  mutate(word = wordStem(word))

total_count <- book_count %>% 
  group_by(Book) %>% 
  summarize(total = sum(n))

book_total_count <- left_join(book_count, total_count)
book_total_count <- book_total_count %>% 
  bind_tf_idf(word, Book, n)

book_total_count %>% 
  arrange(desc(tf_idf)) %>% 
  mutate(blah1 = paste(Book, word)) %>% 
  mutate(blah2 = 1:54847) %>% 
  mutate(blah1 = factor(reorder(blah1, blah2))) %>% 
  group_by(Book) %>% 
  top_n(5, tf_idf) %>% 
  ungroup %>% 
  mutate(blah1 = factor(reorder(blah1, -blah2))) %>% 
  ggplot(aes(blah1, tf_idf, fill = Book)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf", title = "Leading tf-idf words in each book of the Old Testament") +
  facet_wrap(~Book, scales = "free") +
  coord_flip() +
  scale_x_discrete(label = formatter) +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank())

# IViii. Tf_idf: Book-level (New Testament)

new_testament <- king_james_df[king_james_df$Testament=="New Testament",]

new_testament$factorfun <-  as.numeric(factor(king_james_df$King.James.Bible[king_james_df$Testament=="New Testament"], levels = unique(king_james_df$King.James.Bible[king_james_df$Testament=="New Testament"])))

new_testament$King.James.Bible <- factor(reorder(new_testament$King.James.Bible, new_testament$factorfun))

book_count <- new_testament %>% 
  unnest_tokens(word, Text) %>% 
  count(Book = King.James.Bible, word, sort = TRUE) %>% 
  mutate(word = wordStem(word))

total_count <- book_count %>% 
  group_by(Book) %>% 
  summarize(total = sum(n))

book_total_count <- left_join(book_count, total_count)
book_total_count <- book_total_count %>% 
  bind_tf_idf(word, Book, n)

book_total_count %>% 
  arrange(desc(tf_idf)) %>% 
  mutate(blah1 = paste(Book, word)) %>% 
  mutate(blah2 = 1:23731) %>% 
  mutate(blah1 = factor(reorder(blah1, blah2))) %>% 
  group_by(Book) %>% 
  top_n(5, tf_idf) %>% 
  ungroup %>% 
  mutate(blah1 = factor(reorder(blah1, -blah2))) %>% 
  ggplot(aes(blah1, tf_idf, fill = Book)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf", title = "Leading tf-idf words in each book of the New Testament") +
  facet_wrap(~Book, ncol = 6, scales = "free") +
  coord_flip() +
  scale_x_discrete(label = formatter) +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank())